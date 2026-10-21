class_name FluidCircuitDefinition
extends Resource
## A fluid circuit (coolant loop, engine oil, ...) on a vehicle.
##
## Draining happens while the drain fastener is removed; refilling takes fluid
## from inventory at the fill component when its cap is open. Leaks come from
## faults (with leak_rate_l_per_h) on the listed components. Capacities are
## fictional demonstration values.

@export var id: StringName = &""
@export var display_name: String = ""
## Consumable fluid ID taken from inventory when refilling.
@export var fluid_id: StringName = &""
@export var capacity_l: float = 5.0
## Initial fill as a fraction of capacity.
@export var initial_fill: float = 1.0
## Runtime fastener ID of the drain plug/valve.
@export var drain_fastener: StringName = &""
## Litres per real second while draining.
@export var drain_rate_lps: float = 1.5
@export var fill_component: StringName = &""
## Toggle flag on the fill component that represents the filler cap being open.
@export var cap_flag: StringName = &"cap_open"
## Components whose faults can leak this fluid.
@export var leak_components: PackedStringArray = PackedStringArray()
## After refilling, air must be bled (scanner routine) before the circuit is complete.
@export var requires_bleed: bool = false
## Fraction of capacity purged as air when bled (must be topped up afterwards).
@export var bleed_loss_fraction: float = 0.08
## Diagnostic trouble code logged by the level sensor when below low_level_fraction.
@export var low_level_dtc: String = ""
@export var low_level_fraction: float = 0.7
## Diagnostic test ID that pressure-tests this circuit ("" = none).
@export var pressure_test_id: StringName = &""
