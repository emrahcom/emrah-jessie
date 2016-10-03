<?php
$channel = (isset($_GET['channel'])?trim($_GET['channel']):'');
if (!preg_match('/^[a-zA-Z0-9_-]+$/', $channel)) {
    $channel = 'invalid_channel_name'; }
?>
<html>
<head>
    <link href="//vjs.zencdn.net/5.0/video-js.min.css" rel="stylesheet">
    <script src="//vjs.zencdn.net/5.0/video.min.js"></script>
    <script src="/livestream/player/videojs-contrib-hls.min.js"></script>
</head>

<body>
<video id=videojs width=600 height=300 class="video-js vjs-default-skin" controls>
  <source src="/livestream/hls/<?=$channel?>.m3u8" type="application/x-mpegURL">
</video>

<script>
    var player = videojs('videojs');
    player.play();
</script>

</body>
</html>
