const express = require('express');
const app = express();
const port = 3000;

app.get('/auth/callback', (req, res) => {
  // Handle the callback from Microsoft here
  console.log('Callback received with query parameters:', req.query);
  res.send('Callback received! You can close this tab.');
});

app.listen(port, () => {
  console.log(`Server running at http://localhost:${port}`);
});
