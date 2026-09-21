-- Enforce supplier-listing contract field keys for every canonical category.
-- Legacy/benchmark fields remain in the table but are not active form fields.

WITH allowed(category_code,field_code) AS (
  VALUES
    ('hotel','property_type'),('hotel','room_types'),('hotel','board_type'),('hotel','check_in_time'),('hotel','check_out_time'),('hotel','amenities'),('hotel','star_rating'),
    ('holiday_home','property_type'),('holiday_home','bedroom_count'),('holiday_home','bathroom_count'),('holiday_home','guest_capacity'),('holiday_home','pool_type'),('holiday_home','kitchen'),('holiday_home','season_rules'),
    ('yacht','yacht_type'),('yacht','capacity'),('yacht','cabin_count'),('yacht','departure_port'),('yacht','route'),('yacht','captain_included'),('yacht','fuel_policy'),
    ('tour','tour_type'),('tour','duration'),('tour','start_point'),('tour','end_point'),('tour','guide_languages'),('tour','group_size_min'),('tour','group_size_max'),
    ('activity','activity_type'),('activity','duration'),('activity','difficulty'),('activity','age_limit'),('activity','equipment_included'),('activity','meeting_point'),
    ('flight','airline_or_provider'),('flight','route_from'),('flight','route_to'),('flight','fare_class'),('flight','baggage_policy'),('flight','ticket_rules'),
    ('car','vehicle_type'),('car','brand_model'),('car','transmission'),('car','fuel_type'),('car','seat_count'),('car','pickup_locations'),('car','deposit_policy'),
    ('cruise','ship_or_provider'),('cruise','route'),('cruise','departure_port'),('cruise','cabin_types'),('cruise','duration'),('cruise','board_type'),
    ('pilgrimage','package_type'),('pilgrimage','departure_city'),('pilgrimage','duration'),('pilgrimage','hotel_class'),('pilgrimage','visa_included'),('pilgrimage','guidance_included'),
    ('visa','destination_country'),('visa','visa_type'),('visa','processing_time'),('visa','required_documents'),('visa','appointment_required'),
    ('ferry','route_from'),('ferry','route_to'),('ferry','operator'),('ferry','schedule'),('ferry','vehicle_allowed'),('ferry','ticket_rules'),
    ('transfer','transfer_type'),('transfer','pickup_location'),('transfer','dropoff_location'),('transfer','vehicle_type'),('transfer','capacity'),('transfer','waiting_policy'),
    ('beach','beach_name'),('beach','access_type'),('beach','seat_type'),('beach','capacity'),('beach','food_beverage_policy'),('beach','time_slot'),
    ('cinema','venue'),('cinema','movie_or_program'),('cinema','session_time'),('cinema','seat_type'),('cinema','ticket_rules'),
    ('event','event_type'),('event','venue'),('event','start_datetime'),('event','end_datetime'),('event','ticket_type'),('event','age_limit'),
    ('restaurant','cuisine_type'),('restaurant','venue'),('restaurant','reservation_type'),('restaurant','capacity'),('restaurant','menu_options'),('restaurant','service_hours'),
    ('bus','operator'),('bus','route_from'),('bus','route_to'),('bus','seat_type'),('bus','baggage_policy'),('bus','ticket_rules')
)
UPDATE onboarding.category_fields f
SET active=false,
    required=false
WHERE f.category_code IN (SELECT DISTINCT category_code FROM allowed)
  AND NOT EXISTS (
    SELECT 1 FROM allowed a WHERE a.category_code=f.category_code AND a.field_code=f.field_code
  );

WITH allowed(category_code,field_code) AS (
  VALUES
    ('hotel','property_type'),('hotel','room_types'),('hotel','board_type'),('hotel','check_in_time'),('hotel','check_out_time'),('hotel','amenities'),('hotel','star_rating'),
    ('holiday_home','property_type'),('holiday_home','bedroom_count'),('holiday_home','bathroom_count'),('holiday_home','guest_capacity'),('holiday_home','pool_type'),('holiday_home','kitchen'),('holiday_home','season_rules'),
    ('yacht','yacht_type'),('yacht','capacity'),('yacht','cabin_count'),('yacht','departure_port'),('yacht','route'),('yacht','captain_included'),('yacht','fuel_policy'),
    ('tour','tour_type'),('tour','duration'),('tour','start_point'),('tour','end_point'),('tour','guide_languages'),('tour','group_size_min'),('tour','group_size_max'),
    ('activity','activity_type'),('activity','duration'),('activity','difficulty'),('activity','age_limit'),('activity','equipment_included'),('activity','meeting_point'),
    ('flight','airline_or_provider'),('flight','route_from'),('flight','route_to'),('flight','fare_class'),('flight','baggage_policy'),('flight','ticket_rules'),
    ('car','vehicle_type'),('car','brand_model'),('car','transmission'),('car','fuel_type'),('car','seat_count'),('car','pickup_locations'),('car','deposit_policy'),
    ('cruise','ship_or_provider'),('cruise','route'),('cruise','departure_port'),('cruise','cabin_types'),('cruise','duration'),('cruise','board_type'),
    ('pilgrimage','package_type'),('pilgrimage','departure_city'),('pilgrimage','duration'),('pilgrimage','hotel_class'),('pilgrimage','visa_included'),('pilgrimage','guidance_included'),
    ('visa','destination_country'),('visa','visa_type'),('visa','processing_time'),('visa','required_documents'),('visa','appointment_required'),
    ('ferry','route_from'),('ferry','route_to'),('ferry','operator'),('ferry','schedule'),('ferry','vehicle_allowed'),('ferry','ticket_rules'),
    ('transfer','transfer_type'),('transfer','pickup_location'),('transfer','dropoff_location'),('transfer','vehicle_type'),('transfer','capacity'),('transfer','waiting_policy'),
    ('beach','beach_name'),('beach','access_type'),('beach','seat_type'),('beach','capacity'),('beach','food_beverage_policy'),('beach','time_slot'),
    ('cinema','venue'),('cinema','movie_or_program'),('cinema','session_time'),('cinema','seat_type'),('cinema','ticket_rules'),
    ('event','event_type'),('event','venue'),('event','start_datetime'),('event','end_datetime'),('event','ticket_type'),('event','age_limit'),
    ('restaurant','cuisine_type'),('restaurant','venue'),('restaurant','reservation_type'),('restaurant','capacity'),('restaurant','menu_options'),('restaurant','service_hours'),
    ('bus','operator'),('bus','route_from'),('bus','route_to'),('bus','seat_type'),('bus','baggage_policy'),('bus','ticket_rules')
)
UPDATE onboarding.category_fields f
SET active=true
FROM allowed a
WHERE a.category_code=f.category_code AND a.field_code=f.field_code;
