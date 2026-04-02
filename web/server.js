const app = require('./app.js')

// the app is listening on a fixed port

const port = process.env.PORT || 3000
app.listen(port, () => {
  console.log('Server running on port 3000')
})
