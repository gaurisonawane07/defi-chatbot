
const coinSymbol = args[0] || "bitcoin";
const API_URL = `https://api.coingecko.com/api/v3/simple/price?ids=${coinSymbol}&vs_currencies=usd`;



console.log(`Fetching price for ${coinSymbol}`);

const response = await Functions.makeHttpRequest({
  url: API_URL,
  method: "GET",
  headers: {
    "Content-Type": "application/json",
  },
  timeout: 10000 // 10 seconds timeout
});

if (response.error) {
  console.error("API Request Error:", response.error.message, response.error.response);
  throw new Error(`API Request Failed: ${response.error.message}`);
}

const { data } = response;
let formattedData;

if (data && data[coinSymbol] && data[coinSymbol].usd) {
  formattedData = `${coinSymbol.charAt(0).toUpperCase() + coinSymbol.slice(1)} price: $${data[coinSymbol].usd}`;
} else {
  formattedData = `Could not fetch data for ${coinSymbol}.`;
}

console.log("Formatted Data:", formattedData);


return Functions.encodeString(formattedData); 