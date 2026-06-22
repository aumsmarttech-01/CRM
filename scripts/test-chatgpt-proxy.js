#!/usr/bin/env node

const endpoint = process.env.CHATGPT_PROXY_URL || "https://uhdrortamsewvrtqtspv.supabase.co/functions/v1/chatgpt-proxy";
const token = process.env.SUPABASE_ANON_KEY || process.env.SUPABASE_PUBLISHABLE_KEY || process.env.SUPABASE_SECRET_KEY;

if (!token) {
  console.error("Missing SUPABASE_ANON_KEY, SUPABASE_PUBLISHABLE_KEY, or SUPABASE_SECRET_KEY in environment.");
  process.exit(1);
}

const body = {
  prompt: process.argv.slice(2).join(" ") || "Write a haiku about databases.",
  model: process.env.OPENAI_MODEL || "gpt-4o-mini"
};

async function main() {
  const response = await fetch(endpoint, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Authorization": `Bearer ${token}`
    },
    body: JSON.stringify(body)
  });

  const text = await response.text();

  if (!response.ok) {
    console.error(`Request failed: ${response.status} ${response.statusText}`);
    console.error(text);
    process.exit(1);
  }

  try {
    console.log(JSON.stringify(JSON.parse(text), null, 2));
  } catch {
    console.log(text);
  }
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
