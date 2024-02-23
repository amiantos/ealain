const config = require("./config.json");
const { S3Client, PutObjectCommand } = require("@aws-sdk/client-s3");
const fs = require("fs");
const presets = require("./presets.json");
const Mustache = require("mustache");
const { ComfyUIClient } = require("comfy-ui-client");
const join = require("path").join;
const writeFile = require("fs").promises.writeFile;
const sharp = require("sharp");

const r2_client = new S3Client({
  region: "auto",
  endpoint: config.r2_endpoint,
  credentials: {
    accessKeyId: config.r2_access_key_id,
    secretAccessKey: config.r2_secret_access_key,
  },
});

const totalImages = 50;
const serverAddress = "127.0.0.1:8188";
const clientId = "ealain-vp-generator";

const main = async () => {
  createImagesFolder();

  await generateImages();

  // await uploadImages();
};

async function uploadImages() {
  const mainJSON = [];
  for (const prompt of presets) {
    const filesArray = fs.readdirSync(`images/${prompt.id}`);
    const filesURLArray = filesArray.map((file) => config.r2_url_prefix + file);
    const randomElement =
      filesURLArray[Math.floor(Math.random() * filesURLArray.length)];
    mainJSON.push({
      id: prompt.id,
      name: prompt.name,
      preview: randomElement,
      images: filesURLArray,
    });
  }
  fs.writeFileSync("images/latest.json", JSON.stringify(mainJSON, null, 2));

  for (const prompt of presets) {
    const filesArray = fs.readdirSync(`images/${prompt.id}`);
    for (const file of filesArray) {
      const imageBuffer = fs.readFileSync(`images/${prompt.id}/${file}`);
      const command = new PutObjectCommand({
        Bucket: config.r2_bucket,
        Key: `${file}`,
        Body: imageBuffer,
        ContentType: "image/png",
        ACL: "public-read",
      });
      try {
        await r2_client.send(command);
      } catch (err) {
        console.error(err);
      }
    }
  }
  // upload images/latest.json to r2
  const latestJSONBuffer = fs.readFileSync("images/latest.json");
  const command = new PutObjectCommand({
    Bucket: config.r2_bucket,
    Key: "latest.json",
    Body: latestJSONBuffer,
    ContentType: "application/json",
    ACL: "public-read",
  });
  try {
    await r2_client.send(command);
  } catch (err) {
    console.error(err);
  }
}

function createImagesFolder() {
  if (!fs.existsSync("images")) {
    fs.mkdirSync("images");
  }
}

function createRandomPromptFromTemplate(prompt) {
  const template_data = {};
  for (const key in prompt.template_data) {
    const value = prompt.template_data[key];
    template_data[key] = value[Math.floor(Math.random() * value.length)];
  }
  return {
    positive: Mustache.render(prompt.positive_prompt_template, template_data),
    negative: Mustache.render(prompt.negative_prompt_template, template_data),
  };
}

async function generateImages() {
  const client = new ComfyUIClient(serverAddress, clientId);
  await client.connect();
  for (const prompt of presets) {
    console.log("Generating images for " + prompt.name);

    const workflow = JSON.parse(
      fs.readFileSync(`./workflows/${prompt.id}-api.json`)
    );

    var batch_size = 5;
    var repetitions = totalImages / batch_size;
    if (Object.keys(prompt.template_data).length === 0) {
      repetitions = 1;
      batch_size = totalImages;
      console.log("Using high batch_size for prompt " + prompt.name);
    }

    // check if /images/id directory exists and create it if it does not exist
    if (!fs.existsSync("images/" + prompt.id)) {
      fs.mkdirSync("images/" + prompt.id);
    }
    const outputDir = `images/${prompt.id}`;

    // erase contents of outputDir
    const files = fs.readdirSync(outputDir);
    for (const file of files) {
      fs.unlinkSync(join(outputDir, file));
    }

    for (var i = 0; i < repetitions; i++) {
      var prompts = createRandomPromptFromTemplate(prompt);
      var seed = Math.floor(Math.random() * 1000000000000000);
      console.log(
        'Generated prompt: "' +
          prompts.positive +
          " ### " +
          prompts.negative +
          '" | Seed: ' +
          seed
      );
      workflow["6"].inputs.text = prompts.positive;
      workflow["7"].inputs.text = prompts.negative;
      workflow["3"].inputs.seed = seed;
      workflow["5"].inputs.batch_size = batch_size;

      const images = await client.getImages(workflow);

      for (const nodeId of Object.keys(images)) {
        for (const [index, img] of images[nodeId].entries()) {
          const arrayBuffer = await img.blob.arrayBuffer();
          const webpBuffer = await sharp(arrayBuffer)
            .webp({ quality: 100 })
            .toBuffer();
          const outputPath = join(
            outputDir,
            `image-${seed}-${index.toString().padStart(3, "0")}.webp`
          );
          writeFile(outputPath, Buffer.from(webpBuffer));
        }
      }
    }
  }

  await client.disconnect();
}

main();
