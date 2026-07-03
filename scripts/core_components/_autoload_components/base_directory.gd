class_name BaseDirectory
extends Node
## An autoload that hold constants for easy access across the whole project.
## 
## This is a service for providing common references that will be used across all projects and components.
## For game specific constants use the Directory autoload

const QUALITY_SCALES := [1.0, 0.75, 0.5, 0.25]

var CORE_LEVELS: Dictionary = {
	"splash" : "uid://1ta4uyq1kbo4",
	"main_menu" : "uid://boamc4f1glu8m",
	"hub" : "uid://c84xdpmyfa2m6",
	"first_level" : "uid://cnwusdma22ef2",
}
