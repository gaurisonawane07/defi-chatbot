// app/layout.js

// You can import fonts and global CSS here
import "./globals.css";

// You can define metadata for your site
export const metadata = {
  title: "DeFi Chatbot",
  description: "My awesome DeFi chatbot for the Chainlink Hackathon",
};

// This is the RootLayout component
export default function RootLayout({ children }) { // <-- MUST accept a 'children' prop
  return (
    <html lang="en">
      <body>
        {children} {/* <-- MUST render the 'children' prop here */}
      </body>
    </html>
  );
}