const config = require("./config.json");
const { Configuration, OpenAIApi } = require("openai");
const { S3Client, PutObjectCommand } = require("@aws-sdk/client-s3");
const { AIHorde } = require("@zeldafan0225/ai_horde");
const { setTimeout } = require("node:timers/promises");
const fs = require("fs");

const s3_client = new S3Client({
  region: config.aws_region,
  credentials: {
    accessKeyId: config.aws_access_key_id,
    secretAccessKey: config.aws_secret_access_key,
  },
});

const r2_client = new S3Client({
  region: "auto",
  endpoint: config.r2_endpoint,
  credentials: {
    accessKeyId: config.r2_access_key_id,
    secretAccessKey: config.r2_secret_access_key,
  },
});

console.log("Hello World");

const main = async () => {
  var totalResults = [];

  var prompts = [];

  const entries = [
    "i had a wonderful day. For the first time in a long time I went outside and I saw the sun and it didn’t make me want to run inside and kill myself",
    "Sometimes when I sit alone at night, my mind starts racing, and I can’t help but feel consumed by the fear of losing everything I’ve gained, and worse, the fear of not caring when I do.",
    "When I walk home late at night I can't help but feel their eyes following me from the bushes",
  ];

  const negativePrompts = [
    "frame, framing, photo, realistic, text",
    "frame, framing, photo, realistic, text, portrait, face, person, people",
  ]

  const styles = [
    "bauhaus ",
    "geometric ",
    "de stijl ",
  ]

  const colorSchemes = [
    "white, black, red, yellow ",
    "white, black, blue, green ",
    "white, black, yellow, green ",
    "white, black, red, blue",
    "white, black, orange, purple",
    "white, black, red ",
    "white, black, orange ",
    "white, black, yellow ",
    "white, black, green ",
    "white, black, blue ",
    "white, black, purple ",
    "cool colors ",
    "warm colors ",
    "muted colors ",
    "grayscale ",
    "black and white ",
  ]

  for (var i = 0; i < 50; i++) {
    prompts.push("Abstract " + styles[Math.floor(Math.random() * styles.length)] + "art based on the text: \"" + entries[Math.floor(Math.random() * entries.length)] + "\" " + colorSchemes[Math.floor(Math.random() * colorSchemes.length)] + "### " + negativePrompts[Math.floor(Math.random() * negativePrompts.length)]);
  }

  for (prompt of prompts) {
    console.log("Generating prompt: " + prompt);
    const results = await generateImages(prompt);
    console.log(results);

    for (const result of results) {
      const success = await uploadImage(result, prompt);
      if (success) {
        totalResults.push(
          config.r2_url_prefix + "image-" + result.id + ".webp"
        );
      }
    }
  }

  const success = await uploadObject(totalResults);
  if (success) {
    console.log("Successfully uploaded results to S3.");
  } else {
    console.log("Failed to upload results to S3.");
  }
};

async function uploadObject(object) {
  // Convert object to json string, and upload to S3 as "latest.json"
  const command = new PutObjectCommand({
    Bucket: config.s3_bucket,
    Key: "latest.json",
    Body: JSON.stringify(object),
    ContentType: "application/json",
    ACL: "public-read",
  });

  try {
    const response = await s3_client.send(command);
    console.log(response);
    return true;
  } catch (err) {
    console.error(err);
    return false;
  }
}

async function uploadImage(imageObject, prompt) {
  const imageResponse = await fetch(imageObject.url);

  const imageBuffer = await imageResponse.arrayBuffer();
  const fileName = "image-" + imageObject.id + ".webp";
  const txtFileName = "images/image-" + imageObject.id + ".txt";

  fs.writeFileSync("images/" + fileName, Buffer.from(imageBuffer));
  fs.writeFileSync(txtFileName, prompt);

  const command = new PutObjectCommand({
    Bucket: config.r2_bucket,
    Key: fileName,
    Body: imageBuffer,
    ContentType: "image/webp",
    ACL: "public-read",
  });

  try {
    const response = await r2_client.send(command);
    console.log(response);
    return true;
  } catch (err) {
    console.error(err);
    return false;
  }
}

async function generateImages(prompt) {
  const apiKey = config.ai_horde_api_key;
  const ai_horde = new AIHorde({
    client_agent: config.client_agent,
    default_token: apiKey,
  });

  // start the generation of an image with the given payload
  const generation = await ai_horde.postAsyncImageGenerate({
    models: ["Deliberate"],
    prompt: prompt,
    params: {
      steps: 15,
      post_processing: ["RealESRGAN_x4plus"],
      cfg_scale: 5,
      hires_fix: false,
      clip_skip: 1,
      width: 1024,
      image_is_control: false,
      height: 576,
      tiling: false,
      karras: true,
      sampler_name: "k_dpmpp_sde",
      n: 5,
      denoising_strength: 0.75,
      facefixer_strength: 0.75,
    },
    censor_nsfw: false,
    shared: true,
    replacement_filter: true,
    dry_run: false,
    r2: true,
    nsfw: true,
    trusted_workers: true,
    slow_workers: false,
  });
  console.log(generation);

  while (true) {
    const check = await ai_horde.getImageGenerationCheck(generation.id);
    console.log(check);
    if (check.done) {
      console.log("Generation complete.");
      break;
    }
    await setTimeout(3000);
  }

  const generationResult = await ai_horde.getImageGenerationStatus(
    generation.id
  );
  console.log(generationResult);

  var results = [];
  for (const result of generationResult.generations) {
    if (result.censored) {
      continue;
    }
    results.push({ id: result.id, url: result.img });
  }

  return results;
}

main();
