// This script makes a call to the OpenAI API to get a natural language response.
// It requires one secret: `apiKey` for your OpenAI API key.
// It takes two arguments: args[0] is the user's query, args[1] is any on-chain data context.

const userQuery = args[0];
const onchainContext = args[1];

// Ensure the OpenAI API key is provided in secrets
if (!secrets.apiKey) {
  throw Error("OpenAI API Key is not set in secrets. Please upload it to the Chainlink Functions secrets.");
}

// Construct the prompt for the AI model
const prompt = `
  You are a helpful DeFi assistant that explains complex topics in simple terms.
  
  Based on the following on-chain context (if any): "${onchainContext}"

  Answer the user's question: "${userQuery}"
`;

// Make the HTTP request to OpenAI's Chat Completions endpoint
const openAIRequest = Functions.makeHttpRequest({
  url: "https://api.openai.com/v1/chat/completions",
  method: "POST",
  headers: {
    "Authorization": `Bearer ${secrets.apiKey}`,
    "Content-Type": "application/json",
  },
  data: {
    model: "gpt-3.5-turbo",
    messages: [{ role: "user", content: prompt }],
    temperature: 0.7, // A little creativity
  },
  timeout: 9000, // 9 seconds
});

// Await the response from the API
const [response] = await Promise.all([openAIRequest]);

if (response.error) {
    console.error("OpenAI API Error:", JSON.stringify(response));
    throw new Error("Request to OpenAI API failed");
}

// Extract the AI's response text
const result = response.data.choices[0].message.content;

console.log("AI Response:", result);

// Return the result as a string, encoded for the smart contract
return Functions.encodeString(result);