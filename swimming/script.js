function initGraph(notes, mins_per_km, distances, race_mins_per_km, race_kms) {
    var points = [
	{ label: "Mins per km", data: mins_per_km },
	{ label: "Distance (km)", data: distances },
	{ label: "Races m/km", data: race_mins_per_km, lines: { show: false } },
	{ label: "Races km", data: race_kms, lines: { show: false } }
    ];

    var options = { 
	lines: { show: true },
	points: { show: true },
	xaxis: { mode: 'time' },
	yaxis: { min: 0 },
	grid: { hoverable: true },
	legend: { position: "nw" },
	hints: {
	    show: true,
	    showSeriesLabel: false,
	    hintFormatter: function(datapoint) {
		var dt = new Date( datapoint.x );
		var time = dt.getDate();
		time += "/" + dt.getMonth();
		time += "/" + (dt.getYear() + 1900);
		
		return time + " - " + datapoint.y.toFixed(2);
	    }
	}
    };
    $.plot($('#placeholder'), points, options);

    var previousPoint = null;
    $("#placeholder").bind("plothover", function (event, pos, item) {
        if (item) {
            if (previousPoint == null || previousPoint != item.datapoint) {
                previousPoint = item.datapoint;
                
		var time = item.datapoint[0];
		var data = notes[time];
		
		var content = "<table>";
		content += "<tr><th>Date</th><td>" + data.date + "</td></tr>";
		content += "<tr><th>Distance</th><td>" + data.distance + " km</td></tr>";
		content += "<tr><th>Time</th><td>" + data.time + "</td></tr>";
		content += "<tr><th>Notes</th><td>" + data.notes + "</td></tr>";
		content += "</table>";
		$("#tooltip").remove();
                showTooltip(item.pageX, item.pageY, content);
	    }
	}
	else {
            $("#tooltip").remove();
            previousPoint = null;            
	}
    });
}

function showTooltip(x, y, contents) {
    $('<div id="tooltip">' + contents + '</div>').css( {
        position: 'absolute',
        display: 'none',
        top: y + 5,
        left: x + 5,
        border: '1px solid #fdd',
        padding: '2px',
        'background-color': '#fee',
        opacity: 0.80
    }).appendTo("body").fadeIn(200);
}
