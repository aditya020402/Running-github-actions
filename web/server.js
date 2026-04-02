const { app } = require('./app.js')

// the app is listening on a fixed port
app.listen(3000, () => {
  console.log('Server running on port 3000')
})
