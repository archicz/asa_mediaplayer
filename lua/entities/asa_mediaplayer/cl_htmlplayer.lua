return 
[[
<!DOCTYPE html>
<html>
<head>
    <style>
        body, html
        {
            margin: 0;
            padding: 0;
            overflow: hidden;
            height: 100%;
            width: 100%;
        }
        
        #video
        {
            position: absolute;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            pointer-events: none;
        }
    </style>
</head>
<body>
    <video id="video" autoplay muted>
        <source id="videoSource" src="" type="video/webm">
    </video>

    <audio id="audio" autoplay>
        <source id="audioSource" src="" type="audio/webm">
    </audio>

    <script>
        const video = document.getElementById('video');
        const audio = document.getElementById('audio');
        
        function handleMediaReady()
        {
            gmod.requestSync();
        }
        
        video.addEventListener('loadedmetadata', handleMediaReady);
        audio.addEventListener('loadedmetadata', handleMediaReady);
        
        video.addEventListener('loadeddata', handleMediaReady);
        audio.addEventListener('loadeddata', handleMediaReady);

        video.addEventListener('play', handleMediaReady);
        audio.addEventListener('play', handleMediaReady);

        function playMedia(videoUrl, audioUrl)
        {
            const videoSource = document.getElementById('videoSource');
            const audioSource = document.getElementById('audioSource');

            videoSource.src = videoUrl;
            audioSource.src = audioUrl;

            video.load();
            audio.load();
        }

        function checkSync()
        {
            gmod.checkSync(video.currentTime, audio.currentTime);
        }
        
        function seekTo(seconds)
        {
            video.currentTime = seconds;
            audio.currentTime = seconds;
        }
        
        function setVolume(percent)
        {
            const volume = Math.min(Math.max(percent, 0), 100) / 100;
            audio.volume = volume;
        }
    </script>
</body>
</html>
]]