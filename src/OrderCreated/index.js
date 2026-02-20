"use strict";

const https = require("https");
const http = require("http");
const { URL } = require("url");

/**
 * Sends a JSON payload to the given URL using Node.js built-in http/https.
 *
 * @param {string} webhookUrl  - The Teams incoming webhook URL.
 * @param {object} payload     - The message card / Adaptive Card payload.
 * @returns {Promise<void>}
 */
async function postToWebhook(webhookUrl, payload) {
  const parsed = new URL(webhookUrl);
  const body = JSON.stringify(payload);

  return new Promise((resolve, reject) => {
    const options = {
      hostname: parsed.hostname,
      port: parsed.port || (parsed.protocol === "https:" ? 443 : 80),
      path: parsed.pathname + (parsed.search || ""),
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Content-Length": Buffer.byteLength(body),
      },
    };

    const transport = parsed.protocol === "https:" ? https : http;
    const req = transport.request(options, (res) => {
      let data = "";
      res.on("data", (chunk) => { data += chunk; });
      res.on("end", () => {
        if (res.statusCode >= 200 && res.statusCode < 300) {
          resolve();
        } else {
          reject(new Error(`Teams webhook responded with status ${res.statusCode}: ${data}`));
        }
      });
    });

    req.on("error", reject);
    req.write(body);
    req.end();
  });
}

/**
 * Builds a Teams MessageCard payload from the OrderCreated event data.
 *
 * @param {object} data - The event data object.
 * @returns {object} MessageCard payload.
 */
function buildTeamsMessage(data) {
  const {
    orderId = "N/A",
    customerName = "N/A",
    amount = 0,
    currency = "EUR",
    createdAt = new Date().toISOString(),
    sourceSystem = "N/A",
  } = data;

  const formattedAmount = new Intl.NumberFormat("en-US", {
    style: "currency",
    currency,
  }).format(amount);

  return {
    "@type": "MessageCard",
    "@context": "https://schema.org/extensions",
    themeColor: "0078D4",
    summary: `New Order Created: ${orderId}`,
    sections: [
      {
        activityTitle: `📦 New Order Created`,
        activitySubtitle: `Source: ${sourceSystem}`,
        facts: [
          { name: "Order ID",       value: orderId },
          { name: "Customer",       value: customerName },
          { name: "Amount",         value: formattedAmount },
          { name: "Created At",     value: new Date(createdAt).toUTCString() },
          { name: "Source System",  value: sourceSystem },
        ],
        markdown: true,
      },
    ],
  };
}

/**
 * Azure Function entry point – Event Grid trigger.
 *
 * The Event Grid event schema wraps the actual order data in `eventGridEvent.data`.
 *
 * @param {import("@azure/functions").Context} context
 * @param {object} eventGridEvent
 */
module.exports = async function (context, eventGridEvent) {
  context.log("OrderCreated function triggered.");
  context.log("Event received:", JSON.stringify(eventGridEvent, null, 2));

  const teamsWebhookUrl = process.env.TEAMS_WEBHOOK_URL;
  if (!teamsWebhookUrl) {
    throw new Error("TEAMS_WEBHOOK_URL environment variable is not set.");
  }

  const data = eventGridEvent.data || {};
  const message = buildTeamsMessage(data);

  context.log("Posting message to Teams channel...");
  await postToWebhook(teamsWebhookUrl, message);
  context.log("Message posted successfully.");
};

// Export helpers for unit testing
module.exports.buildTeamsMessage = buildTeamsMessage;
module.exports.postToWebhook = postToWebhook;
