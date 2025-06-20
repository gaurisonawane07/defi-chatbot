const userQuery = args[0];
const onchainContext = args[1];

// This line correctly reads the secret you just uploaded.
// The key 'geminiApiKey' matches the key in the JSON you provided in the command.
const geminiApiKey = secrets.geminiApiKey;

if (!geminiApiKey) {
    throw Error("Gemini API Key not found in secrets. Please upload secrets using the Chainlink Functions toolkit.");
}

const API_BASE_URL = "https://generativelanguage.googleapis.com/v1beta/models/";
const MODEL_NAME = "gemini-pro"; 
const API_URL = `${API_BASE_URL}${MODEL_NAME}:generateContent?key=${geminiApiKey}`;

const fullPrompt = `User query: "${userQuery}"\nOn-chain context: "${onchainContext}"\n\nProvide a concise and helpful response.`;

const payload = {
  contents: [{ parts: [{ text: fullPrompt }] }],
};

const response = await Functions.makeHttpRequest({
  url: API_URL,
  method: "POST",
  headers: { "Content-Type": "application/json" },
  data: payload,
  timeout: 15000
});

if (response.error) {
  console.error("Gemini API Request Error:", response.error.message);
  throw new Error(`Gemini API Request Failed`);
}

const result = response.data;

if (result.candidates && result.candidates.length > 0 && result.candidates[0].content.parts[0].text) {
  const generatedText = result.candidates[0].content.parts[0].text;
  return Functions.encodeString(generatedText);
} else {
  console.error("Gemini API Response Structure Unexpected:", JSON.stringify(result, null, 2));
  return Functions.encodeString("Error: AI response format unexpected.");
}