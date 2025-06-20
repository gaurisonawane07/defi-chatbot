
const userQuery = args[0];
const onchainContext = args[1];

const GEMINI_API_KEY = "AIzaSyATrMbUtgm-VayfrAIMf7qYodDIqu8TZQ4"; 
if (!GEMINI_API_KEY || GEMINI_API_KEY === "AIzaSyATrMbUtgm-VayfrAIMf7qYodDIqu8TZQ4") {
    throw Error("Gemini API Key not set. Please edit the ai-request.js file and replace the placeholder text.");
}


const API_BASE_URL = "https://generativelanguage.googleapis.com/v1beta/models/";
const MODEL_NAME = "gemini-pro"; 
const API_URL = `${API_BASE_URL}${MODEL_NAME}:generateContent?key=${GEMINI_API_KEY}`;

const fullPrompt = `User query: "${userQuery}"\nOn-chain context: "${onchainContext}"\n\nProvide a concise and helpful response.`;

const payload = {
  contents: [{ parts: [{ text: fullPrompt }] }],
};


const response = await Functions.makeHttpRequest({
  url: API_URL,
  method: "POST",
  headers: {
    "Content-Type": "application/json",
  },
  data: payload,
  timeout: 15000
});

if (response.error) {
  console.error("Gemini API Request Error:", response.error.message);
  throw new Error(`Gemini API Request Failed`);
}

const result = response.data;

if (result.candidates && result.candidates.length > 0) {
  const generatedText = result.candidates[0].content.parts[0].text;
  console.log("Generated Text:", generatedText);
  return Functions.encodeString(generatedText);
} else {
  console.error("Gemini API Response Structure Unexpected:", JSON.stringify(result, null, 2));
  return Functions.encodeString("Error: AI response format unexpected.");
}