let lastWaitingCount = 0;
let waitingAudio = null;
let currentWaitingCount = 0;
let waitingLabelExpanded = false;
const WAITING_LABEL_SHORT = 'WI';
const WAITING_LABEL_LONG = 'Waiting Incidents';

function updateWaitingLabel() {
    const labelEl = document.getElementById('waiting-label');
    if (!labelEl) {
        return;
    }
    if (currentWaitingCount > 0) {
        labelEl.textContent = waitingLabelExpanded ? WAITING_LABEL_LONG : WAITING_LABEL_SHORT;
    } else {
        labelEl.textContent = WAITING_LABEL_SHORT;
    }
}

setInterval(() => {
    waitingLabelExpanded = !waitingLabelExpanded;
    updateWaitingLabel();
}, 5000);

function playWaitingSound() {
    if (!waitingAudio) {
        waitingAudio = new Audio('notification.wav');
        waitingAudio.volume = 0.7;
    }
    waitingAudio.currentTime = 0;
    waitingAudio.play().catch((err) => {
        console.debug('Waiting incident sound failed:', err);
    });
}

let notifyAudio = null;

function playNotifySound() {
    if (!notifyAudio) {
        notifyAudio = new Audio('notify_sound.wav');
        notifyAudio.volume = 0.7;
    }
    notifyAudio.currentTime = 0;
    notifyAudio.play().catch((err) => {
        console.debug('Notify sound failed:', err);
    });
}

window.addEventListener('message', function(event) {
    const data = event.data;

    if (data.action === 'playNotifySound') {
        playNotifySound();
        return;
    }

    if (data.action === 'hudConfig') {
        const vars = data.vars || {};
        for (const [key, value] of Object.entries(vars)) {
            if (typeof key === 'string' && key.startsWith('--')) {
                document.documentElement.style.setProperty(key, String(value));
            }
        }
        return;
    }

    if (data.action === 'updateHUD') {
        if (data.hidden) {
            document.body.style.display = 'none';
        } else {
            document.body.style.display = 'block';
        }

        if (data.street) document.getElementById('street').textContent = data.street;
        if (data.compass) document.getElementById('compass').textContent = data.compass;
        
        // Ahead
        const currentStreet = data.street ? data.street.trim().toLowerCase() : "";
        const nextStreet = data.ahead ? data.ahead.trim().toLowerCase() : "";
        if (nextStreet && nextStreet !== "" && nextStreet !== currentStreet) {
            document.getElementById('ahead-container').style.display = 'block';
            document.getElementById('ahead').textContent = data.ahead;
        } else {
            document.getElementById('ahead-container').style.display = 'none';
        }

        // Block
        if (data.postal) {
            document.getElementById('block-container').style.display = 'block';
            document.getElementById('block').textContent = data.postal;
        } else {
            document.getElementById('block-container').style.display = 'none';
        }

        if (data.time) document.getElementById('time').textContent = data.time;

        if (data.unit) {
            document.getElementById('unit-container').style.display = 'block';
            document.getElementById('unit').textContent = data.unit;
        } else {
            document.getElementById('unit-container').style.display = 'none';
        }
        
        // Unread
        if (data.unreadCount && data.unreadCount > 0) {
            document.getElementById('unread-container').style.display = 'block';
            document.getElementById('unread').textContent = data.unreadCount;
        } else {
            document.getElementById('unread-container').style.display = 'none';
        }

        const parsedWaiting = Number(data.waitingCount);
        const waitingCount = Number.isFinite(parsedWaiting) ? parsedWaiting : 0;
        currentWaitingCount = waitingCount;
        if (waitingCount > 0) {
            document.getElementById('waiting-container').style.display = 'block';
            document.getElementById('waiting').textContent = waitingCount;
        } else {
            document.getElementById('waiting-container').style.display = 'none';
        }
        updateWaitingLabel();
        if (!data.hidden && waitingCount > lastWaitingCount) {
            playWaitingSound();
        }
        lastWaitingCount = waitingCount;

        if (data.priority) {
            document.getElementById("priority-container").style.display = "block";
            document.getElementById("priority").textContent = data.priority;
        } else {
            document.getElementById("priority-container").style.display = "none";
        }

        // Vehicle HUD Group
        const vehicleHud = document.getElementById('vehicle-hud-group');
        if (data.inVehicle) {
            vehicleHud.classList.add('active');
            document.getElementById('speed').textContent = data.speed;
            if (data.speedUnit) document.getElementById('speed-unit').textContent = data.speedUnit;
            if (data.gear) {
                document.getElementById('gear').textContent = data.gear;
            }
            
            // Speed Reactive
            const speedometer = document.getElementById('speedometer');
            if (data.speed > 100) {
                speedometer.classList.add('speed-high');
            } else {
                speedometer.classList.remove('speed-high');
            }

            // Fuel
            if (data.showFuel) {
                const fuelBar = document.getElementById('fuel-bar');
                const fuelContainer = document.getElementById('fuel-container');
                fuelContainer.style.display = 'block';
                fuelBar.style.width = data.fuel + '%';
                
                if (data.fuel < 20) {
                    fuelBar.classList.add('fuel-low');
                } else {
                    fuelBar.classList.remove('fuel-low');
                }

                if (data.isElectric) {
                    fuelContainer.classList.add('electric');
                } else {
                    fuelContainer.classList.remove('electric');
                }
            } else {
                document.getElementById('fuel-container').style.display = 'none';
            }

            // Status Icons
            const iconEngine = document.getElementById('icon-engine');
            const iconLights = document.getElementById('icon-lights');
            const iconLock = document.getElementById('icon-lock');

            iconEngine.className = 'fas fa-car-battery status-icon';
            if (data.engineHealth < 400) {
                iconEngine.classList.add('status-danger');
            } else if (data.engineHealth < 800) {
                iconEngine.classList.add('status-warning');
            }

            iconLights.className = 'fas fa-lightbulb status-icon';
            if (data.lightsOn || data.highbeamsOn) {
                iconLights.classList.add('status-active');
            }

            iconLock.className = 'fas fa-lock status-icon';
            if (data.lockStatus === 2 || data.lockStatus === 4) {
                iconLock.classList.add('status-danger');
            }
        } else {
            vehicleHud.classList.remove('active');
        }
    }
});
