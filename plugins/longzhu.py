# -*- coding: utf8 -*-
import re

from livestreamer.plugin import Plugin
from livestreamer.plugin.api import http, validate
from livestreamer.stream import RTMPStream, HLSStream
CHANNEL_INFO_URL = "http://api.plu.cn/tga/streams/%s"
STREAM_INFO_URL = "http://livestream.plu.cn/live/getlivePlayurl"
_url_re = re.compile(r"http(s)?://star.longzhu.(?:tv|com)/(?P<domain>\w+)(\?\w+)?")
_channel_schema = validate.Schema(
    {
        "data" : {
            "channel" : {
                "id" : validate.transform(int)
            }
        }
    },
    validate.get("data")
);

_stream_schema = validate.Schema(
    {
        "liveUrl":validate.text
    },
    validate.get("playLines")
)

class Longzhu(Plugin):
    @classmethod
    def can_handle_url(self, url):
        return _url_re.match(url)

    def _get_room_id(self, domain):
        res = http.get(CHANNEL_INFO_URL % domain)
        info = http.json(res, schema=_channel_schema)
        if info is None:
            return False
        roomid = info['channel']['id']
        return roomid

    def _get_stream_info(self, roomid):
        headers = {
            "Referer": self.url,
        }
        params={
            "roomid": roomid
        }
        res = http.get(STREAM_INFO_URL, params=params, headers=headers)
        #print res.text
        return http.json(res)

    def _get_streams(self):
        match = _url_re.match(self.url)
        domain = match.group("domain")

        roomid = self._get_room_id(domain)
        if roomid == False:
            return
        print "roomid: %d" % roomid
        streaminfo = self._get_stream_info(roomid)
        if streaminfo == None:
        	return

        channels = streaminfo["playLines"][0]["urls"]
        
        for channel in channels:
            
            url = channel["securityUrl"]
            #print url
            stream = None
            if channel["ext"] == "rtmp" :
                params = dict(rtmp=url)
                stream = RTMPStream(self.session, params=params, redirect=True)
            elif channel["ext"] == "m3u8" :
                stream = HLSStream(self.session, url)
            if stream != None:
            	yield "live", stream


__plugin__ = Longzhu
