const CLASS_NAME_DISABLED = 'disabled';
const CLASS_NAME_SELECTED = 'selected';

const EVENT_NAME_CLICK = 'click';

const SLOT_NAME_MORNING = 'morning';
const SLOT_NAME_AFTERNOON = 'afternoon';
const SLOT_NAME_FULL_DAY = 'full-day';

const budget = {};
let reservations = {};

const toggleOption = (option) => {
  if (!option.classList.contains(CLASS_NAME_SELECTED)) {
    option.classList.add(CLASS_NAME_SELECTED);
  } else {
    option.classList.remove(CLASS_NAME_SELECTED);
  }

  option.parentElement
    .querySelectorAll('div')
    .forEach((element) => {
      if (element === option) {
        return;
      }
      element.classList.remove(CLASS_NAME_SELECTED);
    });
}

const parkingSpotSlotFilter = (parkingSpot, slot) => {
  switch (slot) {
    case SLOT_NAME_MORNING:
      return parkingSpot.classList.contains('am') || parkingSpot.classList.contains(SLOT_NAME_FULL_DAY);
    case SLOT_NAME_AFTERNOON:
      return parkingSpot.classList.contains('pm') || parkingSpot.classList.contains(SLOT_NAME_FULL_DAY);
    case SLOT_NAME_FULL_DAY:
      return parkingSpot.classList.contains(SLOT_NAME_FULL_DAY);
    default:
  }

  return false;
};

const closeTray = () => {
  const tray = document.querySelector('#parking-spot-status .spectrum-Modal');

  tray.classList.remove('is-open');
};

const openTray = (budget) => {
  const tray = document.querySelector('#parking-spot-status .spectrum-Modal');
  const text = tray.querySelector('section.spectrum-Dialog-content');

  text.textContent = `${budget.currentBudget} of ${budget.maxPerWeek} reservations used for week ${budget.weekNumber}.`;

  tray.classList.add('is-open');

  setTimeout(closeTray, 5000);
};

const updateBudget = (week) => {
  const weekNumber = parseInt(week.getAttribute('data-weeknumber'));
  const maxPerWeek = parseInt(week.getAttribute('data-max-budget'));
  const usedBudget = parseInt(week.getAttribute('data-used-budget'));

  const numSelections = week.querySelectorAll(`.parking-spots .${CLASS_NAME_SELECTED}`).length;
  const currentBudget = usedBudget + numSelections;
  const budgetRemaining = currentBudget - maxPerWeek;

  const budgetStatus = week.querySelector('.week-header .budget');
  budgetStatus.innerHTML = `${currentBudget} of ${maxPerWeek} reservation used.`

  return {
    budgetRemaining,
    currentBudget,
    maxPerWeek,
    weekNumber,
  }
};

const disableAll = (week) => {
  week.querySelectorAll('.slot-options > div').forEach((slotOption) => {
    disableSlotOption(slotOption);
  });
  week.querySelectorAll('.parking-spot:not(.selected)').forEach((parkingSpot) => {
    disableParkingSpot(parkingSpot);
  });
};

const enableAll = (week) => {
  week.querySelectorAll('.slot-options > div').forEach((slotOption) => {
    enableSlotOption(slotOption);
  });
  week.querySelectorAll('.parking-spot:not(.selected)').forEach((parkingSpot) => {
    //enableParkingSpot(parkingSpot);
  });
};

const processParkingSpotToggle = (parkingSpot) => {
  const day = parkingSpot.parentElement.parentElement;
  const date = day.querySelector('.date').getAttribute('data-date');
  const slotOption = day.querySelector('.slot-options .selected');
  const slot = slotOption.classList[0]

  if (parkingSpot.classList.contains(CLASS_NAME_SELECTED)) {
    if (budget.budgetRemaining && budget.budgetRemaining === 0) {
      return;
    }

    const parkingSpotId = day.querySelector('.parking-spots .selected').getAttribute('data-id');
    reservations[date] = { slot, parkingSpotId };
  } else {
    toggleAvailableParkingSpots(
      slotOption,
      parkingSpot.parentElement.querySelectorAll('.parking-spot'),
      slot,
    )
    delete reservations[date];
  }

  const week = day.parentElement;
  const updatedBudget = updateBudget(week);

  openTray(updatedBudget);

  if (updatedBudget.budgetRemaining === 0) {
    disableAll(week);
  } else {
    enableAll(week);
  }

  console.log(JSON.stringify(reservations))
};

const parkingSpotClickHandler = (event) => {
  const parkingSpot = event.target.parentElement;

  toggleOption(parkingSpot);
  processParkingSpotToggle(parkingSpot);
};

const disableParkingSpots = (parkingSpots) => {
  parkingSpots.forEach((parkingSpot) => {
    disableParkingSpot(parkingSpot);
  });
};

const toggleAvailableParkingSpots = (slotOption, parkingSpots, slot) => {
  const candidateSpots = Array.prototype.slice.call(parkingSpots);
  const spotsToEnable = candidateSpots.filter((spot) => parkingSpotSlotFilter(spot, slot));

  disableParkingSpots(parkingSpots);

  if (slotOption.classList.contains(CLASS_NAME_SELECTED)) {
    spotsToEnable.forEach((spot) => {
      enableParkingSpot(spot);
    });
  }
};

const unselectParkingSpot = (day, slotOption) => {
  const selectedParkingSpot = day.querySelector('.parking-spot.selected');
  if (selectedParkingSpot) {
    selectedParkingSpot.classList.remove(CLASS_NAME_SELECTED);
    processParkingSpotToggle(selectedParkingSpot);
  }
};

const slotOptionClickHandler = (event) => {
  const day = event.target.parentElement.parentElement.parentElement;
  const parkingSpots = day.querySelectorAll('.parking-spot');
  const slotOption = event.target.parentElement;
  const slotName = slotOption.classList[0];

  unselectParkingSpot(day, slotOption);
  toggleOption(slotOption);
  toggleAvailableParkingSpots(slotOption, parkingSpots, slotName);
};

const enableSlotOption = (slotOption) => {
  slotOption.classList.remove(CLASS_NAME_DISABLED);
  slotOption.addEventListener(EVENT_NAME_CLICK, slotOptionClickHandler);
};

const disableSlotOption = (slotOption) => {
  slotOption.classList.add(CLASS_NAME_DISABLED);
  if (slotOption.parentElement.parentElement.querySelectorAll('.parking-spot.selected').length === 0) {
    slotOption.classList.remove(CLASS_NAME_SELECTED);
  }
  slotOption.removeEventListener(EVENT_NAME_CLICK, slotOptionClickHandler);
};

const enableParkingSpot = (parkingSpot) => {
  if (parkingSpot.classList.contains('unavailable') || parkingSpot.classList.contains('fully-booked')) {
    return;
  }
  parkingSpot.classList.remove(CLASS_NAME_DISABLED);
  parkingSpot.addEventListener(EVENT_NAME_CLICK, parkingSpotClickHandler);
};

const disableParkingSpot = (parkingSpot) => {
  parkingSpot.classList.add(CLASS_NAME_DISABLED);
  parkingSpot.removeEventListener(EVENT_NAME_CLICK, parkingSpotClickHandler);
};

const initSlotOption = (day, slotName) => {
  const slotOption = day.querySelector(`.${slotName}`);

  if (day.querySelectorAll('.parking-spot.self').length > 0) {
    return;
  }

  const availableSpots = Array.prototype.slice.call(day.querySelectorAll('.parking-spot.available'));
  const availableSlotSpots = availableSpots.filter((spot) => parkingSpotSlotFilter(spot, slotName));

  if (availableSlotSpots.length > 0) {
    enableSlotOption(slotOption);
  }
};

const initSlotOptions = () => {
  document
    .querySelectorAll('#parking-spot-status .week')
    .forEach((week) => {
      const usedBudget = parseInt(week.getAttribute('data-used-budget'));
      const maxPerWeek = parseInt(week.getAttribute('data-max-budget'));

      if (usedBudget >= maxPerWeek) {
        return;
      }

      week.querySelectorAll('.day').forEach((day) => {
        initSlotOption(day, SLOT_NAME_MORNING);
        initSlotOption(day, SLOT_NAME_AFTERNOON);
        initSlotOption(day, SLOT_NAME_FULL_DAY);
      });
    });
};

const createHiddenInput = (name, value) => {
  const input = document.createElement('input');

  input.setAttribute('type', 'hidden');
  input.setAttribute('name', `reservations[]reservation[${name}]`);
  input.setAttribute('value', value)

  return input;
};

const submitForm = (event) => {
  event.preventDefault();

  const form = document.getElementById('reservation-form');
  const status = document.getElementById("parking-spot-status");

  Object.keys(reservations).forEach((date) => {
    const reservation = reservations[date];
    const half_day = reservation.slot === SLOT_NAME_MORNING || reservation.slot === SLOT_NAME_AFTERNOON;
    const am = reservation.slot === SLOT_NAME_MORNING;
    const userId = status.getAttribute('data-user');
    const vehicleId = status.getAttribute('data-vehicle');

    form.appendChild(createHiddenInput('user_id', userId));
    form.appendChild(createHiddenInput('parking_spot_id', reservation.parkingSpotId));
    form.appendChild(createHiddenInput('vehicle_id', vehicleId));
    form.appendChild(createHiddenInput('date', date));
    form.appendChild(createHiddenInput('half_day', half_day));
    form.appendChild(createHiddenInput('am', am));
  });

  form.submit();
};

const initForm = () => {
  document.getElementById('submit-reservations').addEventListener(EVENT_NAME_CLICK, submitForm);
};

document.addEventListener('turbo:load', function () {
  if (!document.getElementById('parking-spot-status')) {
    return;
  }

  initSlotOptions();
  initForm();
});
