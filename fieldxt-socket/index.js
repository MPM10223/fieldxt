var app = require('express')();
var http = require('http').Server(app);
var io = require('socket.io')(http);

app.get('/', function(req, res) {
	res.send('<h1>Hello, world!</h1>');
});

io.on('connection', function(socket) {
	console.log('a user connected.');

	socket.on('disconnect', function() {
		console.log('user disconnected.');
	});

	socket.on('login', function(username, password, company, cb) {
		console.log('LOGIN:', username, password, company);
		cb(1, 'http://localhost:8080');
	});

	socket.on('logout', function(userid) {
		console.log('LOGOUT, userid');
	});

	socket.on('photo', function(userid, photourl) {
		console.log('PHOTO: ', userid, photourl);
	});
});

http.listen(3000, function() {
	console.log('listening on *:3000');
});
