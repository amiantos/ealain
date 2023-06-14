const config = require("./config.json");
const { Configuration, OpenAIApi } = require("openai");
const { S3Client, PutObjectCommand } = require("@aws-sdk/client-s3");
const { AIHorde } = require("@zeldafan0225/ai_horde");
const { setTimeout } = require("node:timers/promises");

const client = new S3Client({
  region: "us-east-1",
  credentials: {
    accessKeyId: config.aws_access_key_id,
    secretAccessKey: config.aws_secret_access_key,
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
    "frame, framing, photo, realistic, text, portrait, face, person, people, eyes, nose, mouth",
  ]

  const styles = [
    "bauhaus ",
    "geometric ",
    "tachisme ",
    "de stijl ",
  ]

  const colorSchemes = [
    "white, black, red, yellow ",
    "white, black, purple, blue, green ",
    "white, black, yellow, green ",
    "white, black, red ",
    "white, black, orange ",
    "white, black, yellow ",
    "white, black, green ",
    "white, black, blue ",
    "white, black, indigo ",
    "white, black, violet ",
    "cool colors only ",
    "warm colors only ",
    "grayscale ",
    "black and white ",
    "three colors only ",
    "two colors only ",
  ]

  for (var i = 0; i < 12; i++) {
    prompts.push("Abstract " + styles[Math.floor(Math.random() * styles.length)] + "art based on the text: \"" + entries[Math.floor(Math.random() * entries.length)] + "\" " + colorSchemes[Math.floor(Math.random() * colorSchemes.length)] + "### " + negativePrompts[Math.floor(Math.random() * negativePrompts.length)]);
  }

  for (prompt of prompts) {
    console.log("Generating prompt: " + prompt);
    const results = await generateImages(prompt);
    console.log(results);

    for (const result of results) {
      const success = await uploadImage(result);
      if (success) {
        totalResults.push(
          "https://ealain.s3.amazonaws.com/image-" + result.id + ".webp"
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
    Bucket: "ealain",
    Key: "latest.json",
    Body: JSON.stringify(object),
    ACL: "public-read",
  });

  try {
    const response = await client.send(command);
    console.log(response);
    return true;
  } catch (err) {
    console.error(err);
    return false;
  }
}

async function uploadImage(imageObject) {
  const imageResponse = await fetch(imageObject.url);

  const command = new PutObjectCommand({
    Bucket: "ealain",
    Key: "image-" + imageObject.id + ".webp",
    Body: await imageResponse.arrayBuffer(),
    ACL: "public-read",
  });

  try {
    const response = await client.send(command);
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
    client_agent: "Ealain:v1.0:https://github.com/amiantos/ealain",
    default_token: apiKey,
  });

  // start the generation of an image with the given payload
  const generation = await ai_horde.postAsyncImageGenerate({
    models: ["Deliberate", "Dreamshaper"],
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
    results.push({ id: result.id, url: result.img });
  }

  return results;
}

main();
