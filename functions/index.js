const functions = require('firebase-functions');
const cors = require('cors')({ origin: true });
const axios = require('axios');

// Proxy function for Google Drive API
exports.proxy = functions.https.onRequest(async (req, res) => {
  cors(req, res, async () => {
    try {
      // Decode the URL passed as a query parameter
      const targetUrl = decodeURIComponent(req.query.url);
      if (!targetUrl) {
        return res.status(400).send('Missing URL parameter');
      }

      // Retrieve the API key securely from Firebase Config
      const apiKey = functions.config().google.api_key;

      // Append the API key to the target URL if it's a Google Drive link
      const urlWithApiKey = targetUrl.includes('drive.google.com')
        ? `${targetUrl}&key=${apiKey}`
        : targetUrl;

      // Fetch the requested resource
      const response = await axios.get(urlWithApiKey);

      // Pass the response back to the client
      res.status(response.status).send(response.data);
    } catch (error) {
      console.error('Error in proxy function:', error.message);
      res.status(500).send({ error: 'Error fetching resource', message: error.message });
    }
  });
});