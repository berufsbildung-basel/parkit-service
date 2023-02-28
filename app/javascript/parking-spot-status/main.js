const CLASS_NAME_DISABLED = 'disabled';
const CLASS_NAME_SELECTED = 'selected';

const EVENT_NAME_CLICK = 'click';

const SLOT_NAME_MORNING = 'morning';
const SLOT_NAME_AFTERNOON = 'afternoon';
const SLOT_NAME_FULL_DAY = 'full-day';

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

const processParkingSpotToggle = (parkingSpotOption) => {
  const date = parkingSpotOption.parentElement.parentElement.querySelector('.date').getAttribute('data-date');

  if (parkingSpotOption.classList.contains(CLASS_NAME_SELECTED)) {
    const slot = parkingSpotOption.parentElement.parentElement.querySelector('.slot-options .selected').classList[0];
    const parkingSpotNumber = parseInt(parkingSpotOption.parentElement.parentElement.querySelector('.parking-spots .selected h3').textContent);

    reservations[date] = { slot, parkingSpotNumber };
  } else {
    delete reservations[date];
  }

  console.log(JSON.stringify(reservations))
};

const parkingSpotClickHandler = (event) => {
  const parkingSpotOption = event.target.parentElement;

  toggleOption(parkingSpotOption);
  processParkingSpotToggle(parkingSpotOption);
};

const toggleAvailableParkingSpots = (slotOption, parkingSpots, slot) => {
  const candidateSpots = Array.prototype.slice.call(parkingSpots);
  const spotsToEnable = candidateSpots.filter((spot) => parkingSpotSlotFilter(spot, slot));

  spotsToEnable.forEach((spot) => {
    if (slotOption.classList.contains(CLASS_NAME_SELECTED)) {
      spot.classList.remove(CLASS_NAME_DISABLED);
      spot.addEventListener(EVENT_NAME_CLICK, parkingSpotClickHandler);
    } else {
      spot.classList.add(CLASS_NAME_DISABLED);
      spot.classList.remove(CLASS_NAME_SELECTED);
      spot.removeEventListener(EVENT_NAME_CLICK, parkingSpotClickHandler);
    }
  });
};

const slotOptionClickHandler = (event) => {
  const day = event.target.parentElement.parentElement.parentElement;
  const parkingSpots = day.querySelectorAll('.parking-spot');
  const slotOption = event.target.parentElement;
  const slotName = slotOption.classList[0];

  toggleOption(slotOption);
  toggleAvailableParkingSpots(slotOption, parkingSpots, slotName);
};

const initReservationSlot = (day, slot) => {
  const slotOption = day.querySelector(`.${slot}`);
  const availableSpots = Array.prototype.slice.call(
    day.querySelectorAll('.parking-spot.available'),
  );

  const availableSlotSpots = availableSpots.filter((spot) => parkingSpotSlotFilter(spot, slot));

  if (availableSlotSpots.length > 0) {
    slotOption.classList.remove(CLASS_NAME_DISABLED);
    slotOption.addEventListener(EVENT_NAME_CLICK, slotOptionClickHandler);
  }
};

const initReservationSlots = () => {
  document
    .querySelectorAll('#parking-spot-status .day')
    .forEach((day) => {
      initReservationSlot(day, SLOT_NAME_MORNING);
      initReservationSlot(day, SLOT_NAME_AFTERNOON);
      initReservationSlot(day, SLOT_NAME_FULL_DAY);
    });
};

document.addEventListener('turbo:load', function () {
  initReservationSlots();
});
