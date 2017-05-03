# -*- coding: utf8 -*-
import re
import random

from livestreamer.plugin import Plugin
from livestreamer.plugin.api import http, validate
from livestreamer.stream import RTMPStream, HLSStream

CHANNEL_INFO_URL = "http://live.afreecatv.com:8057/afreeca/player_live_api.php"
ASSIGN_PATH = "/broad_stream_assign.html" 
CHANNEL_RESULT_ERROR = 0
CHANNEL_RESULT_OK = 1
# original, hd, sd
quality = "original"
_url_re = re.compile(r"http(s)?://afreeca.com/(?P<bid>\w+)(/\d+)?")

_channel_schema = validate.Schema(
    {
        "CHANNEL": {
            "RESULT": validate.transform(int),
            "BNO" : validate.text,
            "CDN" : validate.text,
            "RMD" : validate.text,
        }
    },
    validate.get("CHANNEL")
)
_channel_aid_schema = validate.Schema(
    {
        "CHANNEL": {
            "RESULT": validate.transform(int),
            "AID" : validate.text,
        }
    },
    validate.get("CHANNEL")
)
_stream_schema = validate.Schema(
    {
        validate.optional("view_url"): validate.url(
            scheme=validate.any("rtmp", "http")
        )
    }
)

class AfreecaTV_PC(Plugin):
    @classmethod
    def can_handle_url(self, url):
        return _url_re.match(url)

    def _get_channel_info(self, bid):
        headers = {
            "Referer": "http://play.afreecatv.com",
            "Content-Type":"application/x-www-form-urlencoded; charset=UTF-8",
            }
        params = {
            "bid": bid
            }
        res = http.post(CHANNEL_INFO_URL, data=params, headers=headers)
        #print res.text
        return http.json(res, schema=_channel_schema)

    def _get_hls_key(self, broad_key, bid):
        headers = {
            "Referer": self.url,
            "Content-Type":"application/x-www-form-urlencoded; charset=UTF-8",
            }
        data = {
            "bid": bid,
            "bno": broad_key,
            "type": "pwd",
            "player_type": "html5",
            "quality": quality,
            }
        res = http.post(CHANNEL_INFO_URL, data=data, headers=headers)

        return http.json(res, schema=_channel_aid_schema)

    def _get_stream_info(self, assign_url, cdn, quality, broad_key, type):
        headers = {
            "Referer": self.url,
        }
        params={
            "rtmp":{
                "return_type": cdn,
                "use_cors": "true",
                "cors_origin_url": "play.afreecatv.com",
                "broad_key": "{broad_key}-flash-{quality}-{type}".format(broad_key=broad_key, quality=quality,  type=type),
                "time": 1234.56
            },
            "hls":{
                "return_type": cdn,
                "use_cors": "true",
                "cors_origin_url": "play.afreecatv.com",
                "broad_key": "{broad_key}-flash-{quality}-{type}".format(broad_key=broad_key, quality=quality,  type=type),
                "time": 1234.56
            }
        }
        res = http.get(assign_url, params=params[type], headers=headers)

        return http.json(res, schema=_stream_schema)

    def _get_hls_stream(self, url, cdn, quality, broad_key, bid):
        keyjson = self._get_hls_key(broad_key, bid)
        if keyjson["RESULT"] != CHANNEL_RESULT_OK:
            return
        key = keyjson["AID"]
        print key
        info = self._get_stream_info(url, cdn, quality, broad_key, "hls")
        if "view_url" in info:
            print info["view_url"]
            return HLSStream(self.session, info["view_url"], params=dict(aid=key))

    def _get_rtmp_stream(self, url, cdn, quality, broad_key):
        info = self._get_stream_info(url, cdn, quality, broad_key, "rtmp")
        if "view_url" in info:
            print info["view_url"]
            params = dict(rtmp=info["view_url"])
            return RTMPStream(self.session, params=params, redirect=True)

    def _get_streams(self):
        match = _url_re.match(self.url)
        bid = match.group("bid")

        channel = self._get_channel_info(bid)
        if channel["RESULT"] != CHANNEL_RESULT_OK:
            return
        
        broad_key = channel["BNO"]
        assign_url = channel["RMD"] + ASSIGN_PATH
        cdn = channel["CDN"]
        if not broad_key:
            return

        #rtmp_stream = self._get_rtmp_stream(assign_url, cdn, quality, broad_key)
        #if rtmp_stream:
        #    yield "live", rtmp_stream

        hls_stream = self._get_hls_stream(assign_url, cdn, quality, broad_key, bid)
        if hls_stream:
            yield "live", hls_stream

__plugin__ = AfreecaTV_PC
