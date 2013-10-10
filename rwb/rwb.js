/* jshint strict: false, quotmark: double */
/* global $: false, google: false */
//
// Global state
//
// map     - the map object
// usermark- marks the user's position on the map
// markers - list of markers on the current map (not including the user position)
//
//

//
// First time run: request current location, with callback to Start
//
$(document).ready(function(){
	navigator.geolocation.getCurrentPosition(Start);
});

// Global variables
var map, usermark, markers = [],

UpdateMapById = function(id, tag){
	var rows  = $("#"+id).html().split("\n");

	for (var i=0; i<rows.length; i++) {
		var cols = rows[i].split("\t"),
			lat = cols[0],
			lng = cols[1];

		markers.push(new google.maps.Marker({
			map: map,
			position: new google.maps.LatLng(lat,lng),
			title: tag+"\n"+cols.join("\n")
		}));

	}
},

ClearMarkers = function(){
	// clear the markers
	while (markers.length>0) {
		markers.pop().setMap(null);
	}
},

UpdateMap = function(){
	var color = $("#color");

	color.css("background-color", "white")
		.text("Updating Display...");

	ClearMarkers();

	UpdateMapById("committee_data","COMMITTEE");
	UpdateMapById("candidate_data","CANDIDATE");
	UpdateMapById("individual_data", "INDIVIDUAL");
	UpdateMapById("opinion_data","OPINION");


	color.html("Ready");

	/*if (Math.random()>0.5) {
		color.css("background-color", "blue");
	} else {
		color.css("background-color", "red");
	}*/

},

ViewShift = function(){
	var bounds = map.getBounds(),
		ne = bounds.getNorthEast(),
		sw = bounds.getSouthWest();

	$("#color").css("background-color","white")
		.text("Querying...("+ne.lat()+","+ne.lng()+") to ("+sw.lat()+","+sw.lng()+")");

	// debug status flows through by cookie
	$.get("rwb.pl",
		{
			act:	"near",
			latne:	ne.lat(),
			longne:	ne.lng(),
			latsw:	sw.lat(),
			longsw:	sw.lng(),
			format:	"raw",
			what:	"committees,candidates,individuals,opinions"
		}, function(data){
			$("#data").html(data);
			UpdateMap();
		});
},

Reposition = function(pos){
	var lat = pos.coords.latitude,
		lng = pos.coords.longitude;

	map.setCenter(new google.maps.LatLng(lat,lng));
	usermark.setPosition(new google.maps.LatLng(lat,lng));
},

Start = function(location){
	var lat = location.coords.latitude,
		lng = location.coords.longitude,
		acc = location.coords.accuracy,
		mapc = $("#map");

	map = new google.maps.Map(mapc[0],
		{
			zoom: 16,
			center: new google.maps.LatLng(lat,lng),
			mapTypeId: google.maps.MapTypeId.HYBRID
		});

	usermark = new google.maps.Marker({ map:map,
		position: new google.maps.LatLng(lat,lng),
		title: "You are here"});

	markers = [];

	$("#color").css("background-color", "white")
		.text("Waiting for first position");

	google.maps.event.addListener(map,"bounds_changed",ViewShift);
	//google.maps.event.addListener(map,"center_changed",ViewShift);
	//google.maps.event.addListener(map,"zoom_changed",ViewShift);

	navigator.geolocation.watchPosition(Reposition);
};