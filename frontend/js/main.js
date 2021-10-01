import {Map, View} from 'ol';
import TileLayer from 'ol/layer/Tile';
import XYZ from 'ol/source/XYZ';
import VectorTileLayer from 'ol/layer/VectorTile.js';
import VectorTileSource from 'ol/source/VectorTile.js';
import {Style, Stroke, Fill, Circle} from 'ol/style';
import MVT from 'ol/format/MVT.js';
import Overlay from 'ol/Overlay';


// Container...
const container = document.getElementById('popup');
const content = document.getElementById('popup-content');
var currentLayer = "point"

const overlay = new Overlay({
  element: container,
  autoPan: false,
  autoPanAnimation: {
    duration: 250,
  },
});

// Define Basemap Layer
var cartotiles = new TileLayer({
  source: new XYZ({
    url: 'https://{a-d}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png'
  })
});

// Default Source
var src = new VectorTileSource({
  format: new MVT(),
  attributions: '© <a href="http://www.openstreetmap.org/copyright">OpenStreetMap contributors</a>',
  url: 'https://api.maphub.dev/point/{z}/{x}/{y}'
})

// Default Layers - 
var mainlayer = new VectorTileLayer({
  declutter: false,
  minZoom: 5, // visible at zoom levels above 14
  maxZoom: 18, // visible at zoom levels above 14
  style: new Style({
    image: new Circle({
      radius: 2,
      fill: new Fill({ color: 'black'}),
    }),
    fill: new Fill({
      color: 'rgba(0, 0, 0, 0.01)',
    }),
    stroke: new Stroke({
      color: '#3399CC',
      width: 1.25
    })
  }),
  source: src
});

// Define Map
map = new Map({
  target: 'map',
  layers: [
    cartotiles,
    mainlayer
  ],
  overlays: [
    overlay
  ],
  view: new View({
    center: [-8234010, 4965000], // Tunisia, Test: [1234010, 3965000]
    zoom: 10,
  })
});

// Formatting handler for the JSON textarea 
document.getElementById('filter-json').addEventListener('keydown', function(e) {
if (e.key == 'Tab') {
  e.preventDefault();
  var start = this.selectionStart; var end = this.selectionEnd;

  // set textarea value to: text before caret + tab + text after caret
  this.value = this.value.substring(0, start) + "\t" + this.value.substring(end);

  // put caret at right position again
  this.selectionStart = this.selectionEnd = start + 1;
}
});

// Map Updates - Switch Base Layer (e.g. Polygon -> Point)
const buttons = document.getElementsByClassName('switcher');

// Map Updates....
const matchfilter = (element) => element.match(/http:.+filter=[a-zA-Z0-9]+/g) != null

function updateBaseLayer(path) {
  // Set the Current Layer Var
  var currentFilter = document.getElementById('layer-hash-input').value
  currentLayer = path

  // Update the Path...
  if (src.getUrls().some(matchfilter)){
    src.setUrl("https://api.maphub.dev/" + path + "/{z}/{x}/{y}?filter=" + currentFilter);
  } else {
    src.setUrl("https://api.maphub.dev/" + path + "/{z}/{x}/{y}");
  }
}

for (let i = 0, ii = buttons.length; i < ii; ++i) {
  const button = buttons[i];
  button.addEventListener(
    'click', updateBaseLayer.bind(null, button.value)
  );
}

// Map Updates - Apply Filter (e.g. /point/z/y/x?filter=XXXXX or /point/z/y/x)
const filter_toggle = document.getElementById('enable-filter-toggle');

function enableFilter(){
  
  src.clear()
  if (src.getUrls().some(matchfilter)){
    // If there is a filter on...then toggle it off
    src.setUrl("https://api.maphub.dev/" + currentLayer + "/{z}/{x}/{y}");
  } else {
    // If there isn't, turn one on!
    var currentFilter = document.getElementById('layer-hash-input').value
    src.setUrl(
      "https://api.maphub.dev/" + currentLayer + "/{z}/{x}/{y}?filter=" + currentFilter
    );
  }


  

  
}

filter_toggle.addEventListener(
  'click', enableFilter.bind(null)
)



// Layer Hash -> Layer JSON
const layerHash = document.getElementById('apply-layer-hash');

function hashToLayer(){
  var hash = document.getElementById('layer-hash-input').value
  document.getElementById('filter-json').value = atob(hash); 
}

layerHash.addEventListener(
  'click', hashToLayer.bind(null)
)

// Save to List
map.on('pointermove', function(evt) {
  
  container.style.display = "none";

  map.forEachFeatureAtPixel(evt.pixel, function(feature) {
    // getGeom & getProperty for each geom on hover && activate && set 
    // InnerHTML of pop-up
    const geometry = feature.getGeometry();
    const coordinate = evt.coordinate;
    
    if (geometry) {
      var obj = feature.getProperties();
      content.innerHTML = '<p>' + obj.osm_id + '</p><code>' + JSON.stringify({"tags": obj.tags }, null, 4) + '</code>';
    } 

    // Set Display...
    container.style.display = "block";
    overlay.setPosition(coordinate);
    }, 
    {
      hitTolerance: 2
    });
});

