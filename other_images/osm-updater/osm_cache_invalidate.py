# Cache invalidator reads a change file, locates the updated objects, and invalidates any entries for that
# object in the cache....
import gzip
import math
import os

from lxml import etree

import osmapi as osm
from osmapi.OsmApi import ElementDeletedApiError


# http://osmapi.metaodi.ch/#osmapi.OsmApi.OsmApi.NodeGet
api = osm.OsmApi() 

def osm_get_coords(tag, obj_id):
    if tag not in ('node', 'way'):
        return None, None
    
    if tag == 'node':
        obj = api.NodeGet(obj_id)
        return obj.get('lat'), obj.get('lon')

    elif tag == 'way':
        obj = api.WayGet(obj_id)
        nd_arr = obj.get('nd')
        if nd_arr != []:
            return osm_get_coords('node', nd_arr[0])


def deg2num(lat_deg, lon_deg, zoom):
    lat_rad = math.radians(lat_deg)
    n = 2.0 ** zoom
    xtile = int((lon_deg + 180.0) / 360.0 * n)
    ytile = int((1.0 - math.asinh(math.tan(lat_rad)) / math.pi) / 2.0 * n)
    return (xtile, ytile)


# Unzip
if __name__ == '__main__':

    with gzip.open('/Users/dustinwilson/098.osc.gz', 'rb') as f:
        xml_content = f.read()
        xml = bytes(bytearray(xml_content))
        doc = etree.XML(xml)
        
        for i, elem in enumerate(doc.iter()):
            if elem.tag in ('node', 'way'):
                d = dict(
                    zip(elem.keys(), elem.values())
                )

                obj_id = d.get('id')
                if obj_id:
                    try:
                        lat, lng = osm_get_coords(elem.tag, obj_id)
                        
                        # To Invalidate...
                        x, y = deg2num(lat, lng, 12)
                        print(x, y)
                        
                    except (ElementDeletedApiError) as err:
                        # If elem is deleted, then S.O.L...
                        pass
