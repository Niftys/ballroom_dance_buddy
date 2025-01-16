const functions = require('firebase-functions');
const axios = require('axios');

exports.proxy = functions.https.onRequest(async (req, res) => {
  const targetUrl = req.query.url;

  if (!targetUrl) {
    return res.status(400).send('Missing URL parameter');
  }

  try {
    // Log the target URL for debugging
    console.log(`Fetching URL: ${targetUrl}`);

    // Fetch the target URL
    const response = await axios.get(targetUrl, {
      headers: {
        // Include a Referer header if required by the API key restrictions
        'Referer': 'https://ballroom-dance-buddy.web.app',
      },
    });

    // Forward the response back to the client
    res.set('Access-Control-Allow-Origin', '*'); // Allow cross-origin requests
    res.set('Content-Type', response.headers['content-type']);
    res.status(response.status).send(response.data);
  } catch (error) {
    console.error('Error in proxy function:', error.message);
    res.status(500).send(`Error fetching resource: ${error.message}`);
  }
});