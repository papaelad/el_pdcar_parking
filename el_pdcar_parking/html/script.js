window.addEventListener('message', function(event) {
    if (event.data.action === "openVehicleManager") {
        const vehicles = event.data.vehicles;
        const table = document.getElementById("vehicleTable");
        table.innerHTML = "";

        for (const division in vehicles) {
            vehicles[division].forEach(vehicle => {
                const row = document.createElement("tr");

                const model = vehicle.model || "לא ידוע";
                const coords = vehicle.spawn
                    ? `${vehicle.spawn.x.toFixed(2)}, ${vehicle.spawn.y.toFixed(2)}, ${vehicle.spawn.z.toFixed(2)}`
                    : "לא ידוע";
                const date = vehicle.savedAt
                    ? new Date(vehicle.savedAt * 1000).toLocaleString("he-IL")
                    : "לא ידוע";

                row.innerHTML = `
                    <td>${division}</td>
                    <td>${model}</td>
                    <td>${coords}</td>
                    <td>${date}</td>
                `;
                table.appendChild(row);
            });
        }

        document.querySelector(".main").style.display = "block";
    }
});

document.getElementById("closeBtn").addEventListener("click", function() {
    fetch(`https://${GetParentResourceName()}/closeUI`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({})
    });
    document.querySelector(".main").style.display = "none";
});
