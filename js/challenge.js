// While uploading, the status text paragraph should be updating with the current percentage complete at least once every 2 seconds.
var updateUploadProgress = function() {
	// check upload progess
	$.get('/progress', {'uid': UID}, function(data) {
		if(data.progress < 100) {
			if(data.progress) $('#progress').text('uploading... ' + data.progress + '%');
			setTimeout('updateUploadProgress()',500);
			return true;
		}
		// if progress indicates upload complete, file info
		getStatus();
	}, 'json');
};
// When the upload completes, the status text should display the path on the server to the saved file and the current value of the title text field should be posted to the server
var getStatus = function() {
	$('#progress').html('upload complete!<br />getting file status...');
	// get the file info and display link to file
	$.get('/status', {'uid': UID}, function(data) {
		$('#progress').append('<br />status received!');
		$('#status').html('<a href="'+data.relative+'" target="_blank">'+data.absolute+'</a>');
		postTitle();
	}, 'json');
};
// The response to the form post request should display both the title and the path to the file.
var postTitle = function() {
	$('#progress').append('<br />sending title...');
	// display title along with path to file
	$.post('/title', {
		'uid': UID,
		'title': $('#title').val()
	}, function(data) {
		$('#progress').append('<br />title added!<br /><strong>challenge complete!</strong>');
		$('#status').html('<strong>'+data.title+'</strong> - <a href="'+data.relative+'" target="_blank">'+data.absolute+'</a>');
	}, 'json');
};
