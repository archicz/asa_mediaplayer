<?php
$response = array();
$response['error'] = 0;

function process_video($videoId)
{
	$output = null;
	$retval = null;

	$videoUrl = sprintf('https://www.youtube.com/watch?v=%s', escapeshellarg($videoId));
	$cmd = sprintf('yt-dlp -f "bv*[vcodec=vp9]+ba[acodec=opus]" --print "title,duration" --cookies yt_cookies.txt --get-url %s', $videoUrl);
	exec($cmd, $output, $retval);

	return ($retval == 0) ? $output : null;
}

function is_valid_video($videoId)
{
	return preg_match('/^[A-Za-z0-9_-]{11}$/', $videoId);
}

if (isset($_GET['videoId']))
{
	$videoId = $_GET['videoId'];
	if (is_valid_video($videoId))
	{
		$data = process_video($videoId);

		if ($data[0] != null && $data[2] != null && $data[3] != null)
		{
			$response['title'] = $data[0];
			$response['duration'] = $data[1];
			$response['video'] = $data[2];
			$response['audio'] = $data[3];
		}
		else
		{
			$response['error'] = 1;
			$response['error_info'] = 'This video lacks VP9/Opus (WebM) format';
		}
	}
	else
	{
		$response['error'] = 1;
		$response['error_info'] = 'Invalid video ID';
	}
}
else
{
	$response['error'] = 1;
	$response['error_info'] = 'No link specified';
}

echo json_encode($response);