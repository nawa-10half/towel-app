import {
  BedrockRuntimeClient,
  ConverseCommand,
} from "@aws-sdk/client-bedrock-runtime";

const client = new BedrockRuntimeClient({ region: "ap-northeast-1" });

const MODEL_ID = "jp.anthropic.claude-haiku-4-5-20251001-v1:0";

const SYSTEM_PROMPT = `あなたはタオルの状態を診断する専門家です。
ユーザーが送信したタオルの写真を分析し、以下の4項目を100点満点で評価してください。
点数が高いほど良い状態を意味します。

1. color_fading_score: 色褪せ（100=鮮やかな色、0=完全に色褪せている）
2. stain_score: 汚れ（100=汚れなし、0=ひどい汚れ）
3. fluffiness_score: ふわふわ感（100=新品同様のふわふわ、0=完全にペタンコ）
4. fraying_score: ほつれ（100=ほつれなし、0=ひどいほつれ）

また、overall_score として4項目の総合評価を100点満点で算出してください（単純平均でなく、状態の深刻さを考慮した総合判断）。

日本語でコメント（comment）と推奨アクション（recommendation）も提供してください。

必ず以下のJSON形式のみで回答してください。JSON以外のテキストは含めないでください:
{
  "overall_score": <number>,
  "color_fading_score": <number>,
  "stain_score": <number>,
  "fluffiness_score": <number>,
  "fraying_score": <number>,
  "comment": "<string>",
  "recommendation": "<string>"
}`;

export const handler = async (event) => {
  try {
    const body = JSON.parse(event.body);
    const { image, towel_name, towel_location } = body;

    if (!image) {
      return {
        statusCode: 400,
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ error: "image is required" }),
      };
    }

    const userMessage = towel_name
      ? `このタオル「${towel_name}」（設置場所: ${towel_location || "不明"}）の状態を診断してください。`
      : "このタオルの状態を診断してください。";

    const imageBytes = Buffer.from(image, "base64");

    const response = await client.send(
      new ConverseCommand({
        modelId: MODEL_ID,
        system: [{ text: SYSTEM_PROMPT }],
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
      return {
        statusCode: 500,
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          error: "Failed to parse assessment result",
          raw: textContent.text,
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
    let message = "サーバーで予期しないエラーが発生しました";

    const errorName = error.name || "";

    if (errorName === "ValidationException") {
      statusCode = 400;
      message = "リクエストが不正です。画像データを確認してください";
    } else if (errorName === "AccessDeniedException") {
      statusCode = 403;
      message = "モデルへのアクセスが拒否されました";
    } else if (errorName === "ThrottlingException") {
      statusCode = 429;
      message = "リクエストが多すぎます。しばらく待ってから再試行してください";
    } else if (errorName === "ServiceUnavailableException") {
      statusCode = 503;
      message = "サービスが一時的に利用できません。しばらく待ってから再試行してください";
    } else if (errorName === "ModelTimeoutException") {
      statusCode = 504;
      message = "モデルの応答がタイムアウトしました。再試行してください";
    }

    return {
      statusCode,
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ error: message }),
    };
  }
};
