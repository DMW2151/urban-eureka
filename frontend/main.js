import {Map, View} from 'ol';
import TileLayer from 'ol/layer/Tile';
import XYZ from 'ol/source/XYZ';
import {TileDebug} from 'ol/source';
import VectorTileLayer from 'ol/layer/VectorTile.js';
import VectorTileSource from 'ol/source/VectorTile.js';
import {Style, Stroke, Fill, Circle} from 'ol/style';
import MVT from 'ol/format/MVT.js';

// Define Debug
var debug = new TileLayer({
  source: new TileDebug(),
})

// Define Basemap Layer
var cartotiles = new TileLayer({
  source: new XYZ({
    url: 'https://{a-d}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png'
  })
});


// Default Layers
var point = new VectorTileLayer({
  declutter: false,
  minZoom: 5, // visible at zoom levels above 14
  style: new Style({
    image: new Circle({
      radius: 2,
      fill: new Fill({ color: 'black'}),
    }),
    fill: new Fill({
      color: 'rgba(0, 0, 0, 0.05)',
    })
  }),
  source: new VectorTileSource({
    format: new MVT(),
    attributions:
        '© <a href="https://www.openstreetmap.org/copyright">' +
        'OpenStreetMap contributors</a>',
    url: 'http://localhost:2151/point/{z}/{x}/{y}'
  })
});

var line = new VectorTileLayer({
  declutter: false,
  minZoom: 5, // visible at zoom levels above 14
  style: new Style({
    stroke: new Stroke({
      color: 'red',
      width: 2,
    }),
    fill: new Fill({
      color: 'rgba(255, 0, 0, 0.1)',
    })
  }),
  source: new VectorTileSource({
    format: new MVT(),
    attributions:
        '© <a href="https://www.openstreetmap.org/copyright">' +
        'OpenStreetMap contributors</a>',
    url: 'http://localhost:2151/line/{z}/{x}/{y}'
  })
});

var polygon = new VectorTileLayer({
  declutter: false,
  minZoom: 5, // visible at zoom levels above 14
  style: new Style({
    stroke: new Stroke({
      color: 'green',
      width: 2,
    }),
    // fill: new Fill({
    //   color: 'rgba(0, 255, 0, 0.1)',
    // })
  }),
  source: new VectorTileSource({
    format: new MVT(),
    attributions:
        '© <a href="https://www.openstreetmap.org/copyright">' +
        'OpenStreetMap contributors</a>',
    url: 'http://localhost:2151/polygon/{z}/{x}/{y}'
  })
});

var road = new VectorTileLayer({
  declutter: false,
  minZoom: 5, // visible at zoom levels above 14
  style: new Style({
    stroke: new Stroke({
      color: 'blue',
      width: 2,
    })
  }),
  source: new VectorTileSource({
    format: new MVT(),
    attributions:
        '© <a href="https://www.openstreetmap.org/copyright">' +
        'OpenStreetMap contributors</a>',
        // filter=W3siY29uZGl0aW9uIjogIm9uZW9mIibInByb3RlY3RfY2xhc3MiXX1dCg==
    url: 'http://localhost:2151/roads/{z}/{x}/{y}'
  })
});

// Define Map
map = new Map({
  target: 'map',
  layers: [
    cartotiles,
    point,
    line,
    polygon,
    road,
    //debug,
  ],
  view: new View({
    center: [-8234010 - 180000, 4965000 - 150000],
    zoom: 12,
  })
});


var recent = [];


// Update Logic
function update_recent_objects(item){
  let list = document.getElementById("recent-objects");
  
  // Add the most recent...
  if ((item.tags != "") && (item.tags)){
      let li = document.createElement("li");
      li.innerHTML = `<a><dt class=hanging-indent><b>${item.id}</b></dt> <dd>${item.tags}</dd></a>`
      list.appendChild(li);
  }
}

// Save to List
map.on('pointermove', function(event) {
  
  map.forEachFeatureAtPixel(event.pixel, function(feature) {

    // getGeom & getProperty for each geom on hover && activate && set 
    // InnerHTML of pop-up
    var geometry = feature.getGeometry();
    let active_ids = recent.map(element => element.id)
    
    if (geometry) {
      var obj = feature.getProperties();
      
      // Add to list if not already on list...
      if (!active_ids.includes(obj.osm_id)) {
        recent.push({ "id": obj.osm_id, "tags": obj.tags });
        update_recent_objects({ "id": obj.osm_id, "tags": obj.tags })
      }
    }
  }, 
  {
    hitTolerance: 2
  });
});


// Visibility Control
// function bindInputs(layerid, layer) {

//   var layer_ctl = `${layerid}-control`
//   const visibilityInput = document.getElementById(layer_ctl);
//   console.log("gottem")
  
//   visibilityInput.on('change', function () {
//     layer.setVisible(this.checked);
//   });

//   visibilityInput.prop(
//     'checked', layer.getVisible()
//   );

// }

// function setup(id, group) {

//   group.getLayers().forEach(function (layer, i) {
//     const layerid = id + i;
//     bindInputs(layerid, layer);
//     if (layer instanceof LayerGroup) {
//       setup(layerid, layer);
//     }
//   });

// }

//setup('#layer', map.getLayerGroup());


