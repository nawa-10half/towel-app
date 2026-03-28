import {
  BedrockRuntimeClient,
  ConverseCommand,
} from "@aws-sdk/client-bedrock-runtime";

const client = new BedrockRuntimeClient({ region: "ap-northeast-1" });

const MODEL_ID = "jp.anthropic.claude-haiku-4-5-20251001-v1:0";

const JSON_FORMAT = `{
  "overall_score": <number>,
  "color_fading_score": <number>,
  "stain_score": <number>,
  "fluffiness_score": <number>,
  "fraying_score": <number>,
  "comment": "<string>",
  "recommendation": "<string>"
}`;

function getSystemPrompt(language) {
  const langName = {
    ja: "日本語", en: "English", zh: "中文", ko: "한국어",
    fr: "Français", de: "Deutsch", es: "Español",
    pt: "Português", ru: "Русский", it: "Italiano",
  }[language] || "English";

  return `You are an expert at diagnosing towel conditions.
Analyze the towel photo submitted by the user and evaluate the following 4 criteria on a 100-point scale.
A higher score means a better condition.

1. color_fading_score: Color fading (100=vibrant colors, 0=completely faded)
2. stain_score: Stains (100=no stains, 0=severe stains)
3. fluffiness_score: Fluffiness (100=like new fluffy, 0=completely flat)
4. fraying_score: Fraying (100=no fraying, 0=severe fraying)

Also calculate overall_score as a comprehensive 100-point evaluation of the 4 criteria (not a simple average, but a holistic judgment considering the severity of each condition).

Provide comment and recommendation in ${langName}.

You MUST respond with ONLY the following JSON format. Do not include any text other than JSON:
${JSON_FORMAT}`;
}

function getUserMessage(towelName, towelLocation, language) {
  if (language === "ja") {
    return towelName
      ? `このタオル「${towelName}」（設置場所: ${towelLocation || "不明"}）の状態を診断してください。`
      : "このタオルの状態を診断してください。";
  }
  return towelName
    ? `Please diagnose the condition of this towel "${towelName}" (location: ${towelLocation || "unknown"}).`
    : "Please diagnose the condition of this towel.";
}

export const handler = async (event) => {
  try {
    const body = JSON.parse(event.body);
    const { image, towel_name, towel_location, language } = body;
    const lang = language || "ja";

    if (!image) {
      return {
        statusCode: 400,
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ error: "image is required" }),
      };
    }

    // base64 画像のサイズ制限 (約5MB: base64 は ~33% 大きくなるため 7MB で制限)
    const MAX_BASE64_SIZE = 7 * 1024 * 1024;
    if (image.length > MAX_BASE64_SIZE) {
      return {
        statusCode: 400,
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ error: "Image is too large. Please use an image under 5MB." }),
      };
    }

    const systemPrompt = getSystemPrompt(lang);
    const userMessage = getUserMessage(towel_name, towel_location, lang);
    const imageBytes = Buffer.from(image, "base64");

    const response = await client.send(
      new ConverseCommand({
        modelId: MODEL_ID,
        system: [{ text: systemPrompt }],
        messages: [
          {
            role: "user",
            content: [
              {
                image: {
                  format: "jpeg",
                  source: { bytes: imageBytes },
                },
              },
              { text: userMessage },
            ],
          },
        ],
        inferenceConfig: {
          maxTokens: 1024,
          temperature: 0.3,
        },
      })
    );

    const textContent = response.output?.message?.content?.find(
      (c) => c.text !== undefined
    );
    if (!textContent) {
      return {
        statusCode: 500,
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ error: "No text response from model" }),
      };
    }

    // Extract JSON from response (handle markdown code block wrapper)
    const jsonMatch = textContent.text.match(/\{[\s\S]*\}/);
    if (!jsonMatch) {
      console.error("Failed to parse model response as JSON");
      return {
        statusCode: 500,
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          error: "Failed to parse diagnosis results. Please try again.",
        }),
      };
    }

    const assessment = JSON.parse(jsonMatch[0]);

    return {
      statusCode: 200,
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(assessment),
    };
  } catch (error) {
    console.error("Error:", error);

    let statusCode = 500;
    let message = "An unexpected server error occurred";

    const errorName = error.name || "";

    if (errorName === "ValidationException") {
      statusCode = 400;
      message = "Invalid request. Please check the image data.";
    } else if (errorName === "AccessDeniedException") {
      statusCode = 403;
      message = "Access to the model was denied.";
    } else if (errorName === "ThrottlingException") {
      statusCode = 429;
      message = "Too many requests. Please wait and try again.";
    } else if (errorName === "ServiceUnavailableException") {
      statusCode = 503;
      message = "Service temporarily unavailable. Please wait and try again.";
    } else if (errorName === "ModelTimeoutException") {
      statusCode = 504;
      message = "Model response timed out. Please try again.";
    }

    return {
      statusCode,
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ error: message }),
    };
  }
};
