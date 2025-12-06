window.addEventListener('message', function(event) {
    const data = event.data;

    if (data.type === 'updateHud') {
        // Update compass
        const compass = document.getElementById('compass');
        if (compass) compass.textContent = data.compass || '';

        // Update street name
        const street = document.getElementById('street');
        if (street) street.textContent = data.street || '';

        // Update city
        const city = document.getElementById('city');
        if (city) city.textContent = data.city || '';

        // Update neighborhood
        const neighborhood = document.getElementById('neighborhood');
        if (neighborhood) neighborhood.textContent = data.neighborhood || '';
    }

    if (data.type === 'updateApproaching') {
        const box = document.getElementById('approaching-box');
        const text = document.getElementById('approaching-text');

        if (data.show && data.text) {
            text.textContent = data.text;
            box.classList.remove('hidden');
        } else {
            box.classList.add('hidden');
        }
    }
});
