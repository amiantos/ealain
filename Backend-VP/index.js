const config = require("./config.json");
const { S3Client, PutObjectCommand, paginateListObjectsV2 } = require("@aws-sdk/client-s3");
const { AIHorde } = require("@zeldafan0225/ai_horde");
const { setTimeout } = require("node:timers/promises");
const fs = require("fs");
const presets = require("./presets.json");
const Mustache = require('mustache');

const r2_client = new S3Client({
  region: "auto",
  endpoint: config.r2_endpoint,
  credentials: {
    accessKeyId: config.r2_access_key_id,
    secretAccessKey: config.r2_secret_access_key,
  },
});

const main = async () => {
  // Generate images
  for (const prompt of presets) {
    console.log("Generating images for " + prompt.name)

    const s3Opts = { Bucket: config.r2_bucket, Prefix: prompt.id + "/image"};
    const checkFilesArray = await getAllS3Files(r2_client, s3Opts);
    if (checkFilesArray.length > 20) {
      console.log("Skipping prompt " + prompt.name + " because it already has 20 images.");
      continue;
    }

    for (var i = 0; i < 10; i++) {
      const output = createRandomPromptFromTemplate(prompt);
      console.log("Generated prompt: " + output);

      const params = prompt.params;
      params.n = 3;
      try {
        const results = await generateImages(output, prompt.models, params);
        for (const result of results) {
          const success = await uploadImage(result, prompt.id);
          if (success) { console.log("Saved image " + result.id ); }
        }
      } catch (error) {
        console.error("Error generating image(s): " + error);
      }
    }

    const filesArray = await getAllS3Files(r2_client, s3Opts);
    const filesURLArray = filesArray.map((file) => config.r2_url_prefix + file);
    const success = await uploadObject(JSON.stringify(filesURLArray), prompt.id + "/latest.json");
    if (success) {
      console.log("Successfully uploaded file list to R2.");
    } else {
      console.log("Failed to upload results to R2.");
    }
  }

  // Create main json file
  const mainJSON = [];
  for (const prompt of presets) {
    const s3Opts = { Bucket: config.r2_bucket, Prefix: prompt.id + "/image"};
    const filesArray = await getAllS3Files(r2_client, s3Opts);
    const filesURLArray = filesArray.map((file) => config.r2_url_prefix + file);
    const randomElement = filesURLArray[Math.floor(Math.random() * filesURLArray.length)];
    mainJSON.push({ id: prompt.id, name: prompt.name, preview: randomElement, images: config.r2_url_prefix + prompt.id + "/latest.json" });
  }
  const success = await uploadObject(JSON.stringify(mainJSON), "latest.json");
    if (success) {
      console.log("Successfully uploaded file list to R2.");
    } else {
      console.log("Failed to upload results to R2.");
    }

};

async function uploadObject(string, key) {
  // Convert object to json string, and upload to S3 as "latest.json"
  const command = new PutObjectCommand({
    Bucket: config.s3_bucket,
    Key: key,
    Body: string,
    ACL: "public-read",
  });

  try {
    await r2_client.send(command);
    return true;
  } catch (err) {
    console.error(err);
    return false;
  }
}

const getAllS3Files = async (client, s3Opts) => {
  const totalFiles = [];
  for await (const data of paginateListObjectsV2({ client }, s3Opts)) {
    totalFiles.push(...(data.Contents ?? []));
  }
  return totalFiles.map((file) => file.Key);
};

function createRandomPromptFromTemplate(prompt) {
  const template_data = {};
    for (const key in prompt.template_data) {
      const value = prompt.template_data[key];
      template_data[key] = value[Math.floor(Math.random() * value.length)];
    }
    return Mustache.render(prompt.prompt_template, template_data);
}

async function uploadImage(imageObject, id) {
  // check if /images directory exists and create it if it does not exist
  if (!fs.existsSync("images")) {
    fs.mkdirSync("images");
  }

  //c heck if /images/id directory exists and create it if it does not exist
  if (!fs.existsSync("images/" + id)) {
    fs.mkdirSync("images/" + id);
  }

  const imageResponse = await fetch(imageObject.url);
  const imageBuffer = await imageResponse.arrayBuffer();
  const fileName = id + "/image-" + imageObject.id + ".webp";
  const localFileName = "images/" + fileName;

  fs.writeFileSync(localFileName, Buffer.from(imageBuffer));

  const command = new PutObjectCommand({
    Bucket: config.r2_bucket,
    Key: fileName,
    Body: imageBuffer,
    ContentType: "image/webp",
    ACL: "public-read",
  });

  try {
    const response = await r2_client.send(command);
    return true;
  } catch (err) {
    console.error(err);
    return false;
  }
}

async function generateImages(prompt, models, params) {
  const apiKey = config.ai_horde_api_key;
  const ai_horde = new AIHorde({
    client_agent: config.client_agent,
    default_token: apiKey,
  });

  // start the generation of an image with the given payload
  const generation = await ai_horde.postAsyncImageGenerate({
    models: models,
    prompt: prompt,
    params: params,
    censor_nsfw: false,
    shared: true,
    replacement_filter: true,
    dry_run: false,
    r2: true,
    nsfw: true,
    trusted_workers: true,
    slow_workers: false,
  });
  console.log(
    "Generation Submitted, ID: " +
      generation.id +
      ", kudos cost: " +
      generation.kudos
  );

  while (true) {
    const check = await ai_horde.getImageGenerationCheck(generation.id);
    if (check.done) {
      console.log("Generation complete.");
      break;
    }
    await setTimeout(3000);
  }

  const generationResult = await ai_horde.getImageGenerationStatus(
    generation.id
  );

  var results = [];
  for (const result of generationResult.generations) {
    if (generationResult.gen_metadata) {
      console.log("Generation metadata:");
      for (const metadata of generationResult.gen_metadata) {
        console.log(metadata);
      }
    }
    if (result.censored) {
      console.error("Censored image detected! Image discarded...");
    } else {
      results.push({ id: result.id, url: result.img });
    }
  }

  return results;
}

main();
