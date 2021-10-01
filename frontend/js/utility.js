/*
*
* Utility Functions for BASIC! map frontend...
*
*/

function keyboard_navig(event){

    // zoom control
    var keynum;
    const view = map.getView();
    const zoom = view.getZoom();

    // Handle for IE/Egde & Netscape/Firefox/Opera                 
    if(window.event) {
        keynum = event.keyCode;
    } else if (event.which) { 
        keynum = event.which;
    }
    
    // If press Shift+ up arrow => ZOOM IN
    if ((keynum == 38) && (event.shiftKey == true)){
        view.setZoom(zoom + 0.5);
    }

    // If press Shift+ down arrow => ZOOM OUT
    if ((keynum == 40) && (event.shiftKey == true)){
        view.setZoom(zoom - 0.5);
    }
}

function toggle_elem(elemid) {

    // Check Current State of Overlay Objects...
    display = document.getElementById("overlay").style.display

    if (display == "none") {
        // Make Visible
        document.getElementById("overlay").style.display = "block";
        document.getElementById(elemid).style.display = "block";
        document.getElementById(elemid).style.visibility = "visible";
    } else if (display == "block") {
        // Make Hidden
        document.getElementById("overlay").style.display = "none";
        var els = document.getElementsByClassName("overlay");

        // `About` Overlay and any others that are created; clears overlays
        Array.prototype.forEach.call(els, function(el) {
            el.style.visibility = "none"
            el.style.display = "none"
        });
    }
}

function prettyPrint() {
    var orig = document.getElementById('filter-json').value;
    
    try {
      var obj = JSON.parse(orig);
      
      // Format the JSON Box
      document.getElementById('filter-json').value = JSON.stringify(obj, undefined, 2);;
      document.getElementById('filter-json').style.backgroundColor = "rgb(0, 255, 255, 0.2)"

      // Update the Hash Box
      document.getElementById('layer-hash-input').value = btoa(orig);

    } catch(err) {
      document.getElementById('filter-json').style.backgroundColor = "rgb(255, 0, 0, 0.2)"
    }
}
