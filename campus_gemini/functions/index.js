const functions = require("firebase-functions");
const fetch = require("node-fetch");

exports.askGemini = functions.https.onRequest(async (req, res) => {
  try {
    const { userQuestion, dbQuestions } = req.body;

    if (!userQuestion || !dbQuestions) {
      return res.status(400).json({ error: "Missing data" });
    }

    const apiKey = "AIzaSyA5HPWuI6JrwcswmqBSQbtdzg9lvuVwnFU";

    const dbText = dbQuestions
      .map(q => `Q: ${q.question} | A: ${q.answer}`)
      .join("\n");

    const prompt = `
You are an AI assistant for a college help platform.

A student has asked the following question:
"${userQuestion}"

Below is a list of existing college questions with answers:
${dbText}

Task:
1. Check if the student question is semantically similar in meaning to any of the existing questions.
2. If a similar question exists, return ONLY the answer of the best matching question.
3. Rewrite the answer in very simple, student-friendly English.
4. If no relevant question exists, respond with exactly: NO_MATCH
`;

    const response = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent?key=${apiKey}`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          contents: [{ parts: [{ text: prompt }] }]
        })
      }
    );

    const data = await response.json();

    if (!data.candidates) {
      return res.json({ result: "NO_MATCH" });
    }

    const text =
      data.candidates[0].content.parts[0].text.trim();

    return res.json({ result: text });
  } catch (error) {
    console.error(error);
    return res.status(500).json({ error: "Gemini error" });
  }
});
