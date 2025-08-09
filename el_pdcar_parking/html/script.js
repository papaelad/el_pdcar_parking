function closeUI() {
    fetch(`https://${GetParentResourceName()}/closeUI`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({})
    }).catch(err => console.error(err));
}

window.addEventListener('message', function(event) {
    const mainContainer = document.querySelector(".main");

    if (event.data.action === "openVehicleManager") {
        const vehicles = event.data.vehicles;
        const table = document.getElementById("vehicleTable");
        table.innerHTML = ""; // Clear previous entries

        for (const division in vehicles) {
            if (vehicles.hasOwnProperty(division)) {
                vehicles[division].forEach((vehicle, index) => {
                    const row = document.createElement("tr");
                    const model = vehicle.model || "לא ידוע";
                    const coords = vehicle.spawn ? `${vehicle.spawn.x.toFixed(2)}, ${vehicle.spawn.y.toFixed(2)}, ${vehicle.spawn.z.toFixed(2)}` : "לא ידוע";
                    const date = vehicle.savedAt ? new Date(vehicle.savedAt * 1000).toLocaleString("he-IL") : "לא ידוע";

                    row.innerHTML = `
                        <td>${division}</td>
                        <td>${model}</td>
                        <td>${coords}</td>
                        <td>${date}</td>
                        <td><button class="delete-btn" data-division="${division}" data-index="${index + 1}">מחק</button></td>
                    `;
                    table.appendChild(row);
                });
            }
        }
        mainContainer.style.display = "block";
    } else if (event.data.action === "close") {
        mainContainer.style.display = "none";
    }
});

document.getElementById("closeBtn").addEventListener("click", closeUI);

document.addEventListener("keydown", function(event) {
    if (event.key === "Escape") {
        closeUI();
    }
});

document.getElementById("vehicleTable").addEventListener("click", function(event) {
    if (event.target && event.target.classList.contains('delete-btn')) {
        const division = event.target.getAttribute('data-division');
        const index = event.target.getAttribute('data-index');

        fetch(`https://${GetParentResourceName()}/deleteVehicle`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ division: division, index: parseInt(index) })
        }).catch(err => console.error(err));
    }
});
