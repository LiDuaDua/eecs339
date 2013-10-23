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

// Global variables
var map, usermark, markers = [], userlocation = {}, categories = "all",
cycles = "'0102','0304','0506','0708','0910','1112','1314','7980','8182','8384','8586','8788','8990','9192','9394','9596','9798','9900'",

UpdateMapById = function(id, tag){
	var data = $("#"+id).html();
	if(data && data.length > 0){
		var rows  = data.split("\n"),
			colors = {
				"-1":"rep.png",
				"0":"nut.png",
				"1":"dem.png"
			};

		for (var i=0; i<rows.length; i++) {
			var cols = rows[i].split("\t"),
				lat = cols[0],
				lng = cols[1];

			if(tag == "OPINION"){
				markers.push(new google.maps.Marker({
					map: map,
					position: new google.maps.LatLng(lat,lng),
					title: tag+"\n"+cols.join("\n"),
					icon: colors[cols[2]]
				}));

			}else{
				markers.push(new google.maps.Marker({
					map: map,
					position: new google.maps.LatLng(lat,lng),
					title: tag+"\n"+cols.join("\n")
				}));
			}
		}
	}
},

ClearMarkers = function(){
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
	UpdateMapById("individual_data","INDIVIDUAL");
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

	Delay(function(){
		$("#color").css("background-color","white")
			.text("Querying...("+Math.round(ne.lat())+","+Math.round(ne.lng())+")");

		$.ajax({
			url: "rwb.pl",
			async: true,
			data: {
				act:	"near",
				cycle:	cycles,
				latne:	ne.lat(),
				longne:	ne.lng(),
				latsw:	sw.lat(),
				longsw:	sw.lng(),
				format:	"raw",
				what:	categories,
			},
			success: function(data){
				$("#data").html(data);
				UpdateMap();
			}
		});
	},1000);
},

Reposition = function(pos){
	var lat = pos.coords.latitude,
		lng = pos.coords.longitude;

	map.setCenter(new google.maps.LatLng(lat,lng));
	usermark.setPosition(new google.maps.LatLng(lat,lng));
},

//nifty delay utility from http://stackoverflow.com/questions/2854407/javascript-jquery-window-resize-how-to-fire-after-the-resize-is-completed
Delay = (function(){
  var timer = 0;
  return function(callback, ms){
    clearTimeout (timer);
    timer = setTimeout(callback, ms);
  };
})(),

Start = function(loc){
	var lat = loc.coords.latitude,
		lng = loc.coords.longitude,
		//acc = loc.coords.accuracy,
		mapc = $("#map");

	userlocation.lat = lat;
	userlocation.lng = lng;

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

$(document).ready(function(){
	navigator.geolocation.getCurrentPosition(Start);

	var data = {}, name, val;
	$("form").on("submit",function(){
		$(this).find("input").each(function(i,el){
			name = $(el).attr("name");
			val = $(el).val();

			//only take active radio elements
			if($(el).attr("type") != "radio" || $(el).parent().hasClass("active")){
				data[name] = val;

				//a bit hacky, but I know that if I'm doing active radio elements, I need user location.
				data.lat = userlocation.lat;
				data.lng = userlocation.lng;
			}
		});

		$.ajax({
			url: "./rwb.pl",
			data: data,
			success: function(reply){
				$("<div />").addClass("alert alert-info").html(reply).prependTo(".container");
				$("<button type=\"button\" class=\"close\" data-dismiss=\"alert\" aria-hidden=\"true\">&times;</button>").appendTo(".alert");
			}
		});
	});

	$(".showcats").on("change",function(){
		categories = "";
		var tmp = [];

		$(".showcats:checked").each(function(){
			tmp.push($(this).attr("name"));
		});

		categories = tmp.join(",");
		ViewShift();
	});

	$("#showcycles").on("change",function(){
		var tmp = $("#showcycles").val();

		for(var i=0; i < tmp.length; i++){
			tmp[i] = "'"+tmp[i]+"'";
		}

		cycles = tmp.join(",");
		ViewShift();
	});

	$("#getaggregate").on("click",function(){
		NProgress.start();
		$(this).button("loading");

		var bounds = map.getBounds(),
			ne = bounds.getNorthEast(),
			sw = bounds.getSouthWest();

		$.ajax({
			url: "./rwb.pl",
			async: true,
			data: {
				act:	"aggregate",
				cycle:	cycles,
				latne:	ne.lat(),
				longne:	ne.lng(),
				latsw:	sw.lat(),
				longsw:	sw.lng(),
				format:	"raw",
				what:	categories,
			},
			success: function(data){
				NProgress.done();
				$("#getaggregate").button("reset");
				$("#summary").html(data);
			}
		});
	});

	//pop up join modal if it exists
	if($("#join").length){
		$("#join").modal("show");
	}

	//lazy: making login complaint if empty div exists
	if($("#logincomplain").length){
		$("<div />").addClass("alert alert-warning").text("Login failed. Try again.").prependTo(".container");
		$("<button type=\"button\" class=\"close\" data-dismiss=\"alert\" aria-hidden=\"true\">&times;</button>").appendTo(".alert-warning");
	}
});