
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

function search_tags(){

    var input, filter, ul, li, a, i, txtValue;
    input = document.getElementById("object-search");
    filter = input.value.toUpperCase();
    ul = document.getElementById("recent-objects");
    li = ul.getElementsByTagName("li");

    for (i = 0; i < li.length; i++) {
        a = li[i].getElementsByTagName("a")[0];
        txtValue = a.textContent || a.innerText;
        if (txtValue.toUpperCase().indexOf(filter) > -1) {
            li[i].style.display = "";
        } else {
            li[i].style.display = "none";
        }
    }
}

function toggle_about() {

    // Check Current State of Overlay Objects...
    display = document.getElementById("overlay").style.display

    if (display == "none") {
        // Make Visible
        document.getElementById("overlay").style.display = "block";
        document.getElementById("about-overlay").style.display = "block";
        document.getElementById("about-overlay").style.visibility = "visible";
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

