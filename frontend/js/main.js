import {Map, View} from 'ol';
import TileLayer from 'ol/layer/Tile';
import XYZ from 'ol/source/XYZ';
import VectorTileLayer from 'ol/layer/VectorTile.js';
import VectorTileSource from 'ol/source/VectorTile.js';
import {Style, Stroke, Fill, Circle} from 'ol/style';
import MVT from 'ol/format/MVT.js';
import Overlay from 'ol/Overlay';
import {ScaleLine, defaults as defaultControls} from 'ol/control';

// Container for object labels...
const container = document.getElementById('popup');
const content = document.getElementById('popup-content');
var currentLayer = "point"

// Default Source - Query our backend service - tiles.maphub.dev - for geometry data
var src = new VectorTileSource({
  format: new MVT(),
  attributions: '© <a href="http://www.openstreetmap.org/copyright">OpenStreetMap contributors</a>',
  url: 'https://tiles.maphub.dev/point/{z}/{x}/{y}'
})

// Adjust URL
function urlAdjust(){
  var url = new URL(window.location.href)
  var filterHash = url.searchParams.get("filter");
  if ((filterHash != null) && (filterHash != "")){

    // Set Hash on Start
    document.getElementById('layer-hash-input').value = filterHash

    // Set Docs on Start
    document.getElementById('filter-json').value = atob(filterHash); 


    // Set Src URL...
    src.clear()
    src.setUrl(
      "https://tiles.maphub.dev/" + currentLayer + "/{z}/{x}/{y}?filter=" + filterHash
    );
  }
}

urlAdjust()

/* Define Map Elements - Overlay, Tilelayer, Tilesource(s) */
// Define Overlay - tags will appear w. no animatiton over the main map...
const overlay = new Overlay({
  element: container
});

// Define Basemap Layer - Use the Carto Test Map
var cartotiles = new TileLayer({
  source: new XYZ({
    url: 'https://{a-d}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png'
  })
});



// Define Scale Bar for sizing regions...
function scaleControl() {
  var control = new ScaleLine({
    units: 'metric',
    bar: false,
    text: true,
    minWidth: 500,
  });
  
  return control;
}

// Default Layers - Set the styling for the default layer, also keep src isolated s.t. it can
// be manipulated independently of `mainlayer`
//
// To prevent massive queries - make visible at zoom levels above (lower) than 5 
// and (higher) than 18 (e.g. won't try to return 1000km^2 areas or 1^m areas, do this to save
// some API calls...)
var mainlayer = new VectorTileLayer({
  minZoom: 5,
  maxZoom: 20,
  // Points == Black
  // Polygon, Line, Roads == Light Blue
  style: new Style({
    image: new Circle({
      radius: 3,
      fill: new Fill({ color: 'black'}),
    }),
    stroke: new Stroke({
      color: '#204068',
      width: 1.25
    })
  }),
  source: src
});


// Define Main Map Object....
map = new Map({
  controls: defaultControls().extend([scaleControl()]),
  target: 'map',
  layers: [
    cartotiles,
    mainlayer
  ],
  overlays: [
    overlay
  ],
  // Default view starts in NYC
  view: new View({
    // center - Test 01 (Tunisia): [1234010, 3965000], 
    // center - Test 02 (NYC): [-8234010, 4965000], 
    center: [-8234010 - 160000, 4965000 - 160000], 
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


// Updates for the Map's active layer...

/* Map Updates - Switch Base Layer (e.g. Polygon -> Point) */
const buttons = document.getElementsByClassName('switcher');

const matchfilter = (element) => element.match(/http:.+filter=[a-zA-Z0-9]+/g) != null

function updateBaseLayer(path) {
  var currentFilter = document.getElementById('layer-hash-input').value
  currentLayer = path

  src.clear()
  // Update the Path...
  if (src.getUrls().some(matchfilter)){
    src.setUrl("https://tiles.maphub.dev/" + path + "/{z}/{x}/{y}?filter=" + currentFilter);
  } else {
    src.setUrl("https://tiles.maphub.dev/" + path + "/{z}/{x}/{y}");
  }
}

// Bind Switcher to the Buttons on the Navbar...
for (let i = 0, ii = buttons.length; i < ii; ++i) {
  const button = buttons[i];
  button.addEventListener(
    'click', updateBaseLayer.bind(null, button.value)
  );
}


/* Map Updates - Apply Filter (e.g.  /point/z/y/x -> /point/z/y/x?filter=XXXXX) */
const filter_toggle = document.getElementById('enable-filter-toggle');

function enableFilter(){
  var currentFilter = document.getElementById('layer-hash-input').value
  src.clear()
  src.setUrl(
    "https://tiles.maphub.dev/" + currentLayer + "/{z}/{x}/{y}?filter=" + currentFilter
  ); 
}

filter_toggle.addEventListener(
  'click', enableFilter.bind(null)
)

/* Map Updates - Remove Filter (e.g. /point/z/y/x?filter=XXXXX -> /point/z/y/x) */
const clear_filter_toggle = document.getElementById('clear-filter-toggle');

function clearFilter(){
  // Clear the Hashes and Content of the Layer Definition Bar...s
  document.getElementById('layer-hash-input').value = ""
  document.getElementById('filter-json').value = ""

  src.clear()
  src.setUrl(
    "https://tiles.maphub.dev/" + currentLayer + "/{z}/{x}/{y}"
  );
}

clear_filter_toggle.addEventListener(
  'click', clearFilter.bind(null)
)


// Get Layer Hash and Generate a Layer JSON
const layerHash = document.getElementById('apply-layer-hash');

function hashToLayer(){
  var hash = document.getElementById('layer-hash-input').value
  document.getElementById('filter-json').value = atob(hash); 
}

layerHash.addEventListener(
  'click', hashToLayer.bind(null)
)

// Apply pop-up on hover - Allow user to see the obj tags...
map.on('pointermove', function(evt) {
  
  container.style.display = "none";

  map.forEachFeatureAtPixel(evt.pixel, function(feature) {
    // getGeom & getProperty for each geom on hover && activate && set InnerHTML of pop-up
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

