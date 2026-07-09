# **Custom GDScript Style Guide**

This guide establishes the coding standards for our Godot projects. It is a combination of the [Official Godot Style Guide](https://www.google.com/search?q=https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_style_guide.html), the [Auto-Documentation syntax](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_documentation_comments.html), and custom preferences regarding commenting and inline documentation. Refer to this style guide when editing or creating scripts.

## **1\. Documentation & Comments**

Documentation is essential for generating automatic help files within the Godot Editor. We adhere to a specific hierarchy for comments to keep code clean.

### **Script-Level Documentation**

* **Format:** Block \#\# comments at the very top of the file.  
* **Content:** This is the *only* place for long descriptions. Explain what the script is, how to use it, and any complex implementation details here.  
* **Syntax:**  
  class\_name MyClass  
  extends Node  
  \#\# Brief description of the class.  
  \#\#  
  \#\# A detailed description follows here. This is where you explain the   
  \#\# logic, usage patterns, and implementation details so the rest   
  \#\# of the script can remain clean.  
* Remember to use the \[br\] tag to add line breaks, for example if adding numbered lists to the detailed description

### **Public Members (In-line Documentation)**

* **Preference:** Favor **in-line** documentation comments for variables, signals, and public functions.  
* **Conciseness:** Keep these descriptions extremely short. If it requires a paragraph, move the explanation to the Script-Level Documentation.  
* **Syntax:** Use \#\# at the end of the line.  
  signal player\_died \#\# Emitted when health reaches zero

  @export var max\_speed: float \= 100.0 \#\# Maximum movement speed in pixels/sec

  func attack(target: Node): \#\# Calculates damage and applies it to target  
      pass

### **Private Members**

* **Naming:** Must start with an underscore \_.  
* **Comments:** Do **not** use \#\#. Use a single \# comment in-line with the function definition if a note is required.  
* **Syntax:**  
  func \_recalculate\_path(): \# Updates navigation path on a background thread  
      pass

### **Section headers**

* Use single \# comments written in **CAPITAL LETTERS** to separate broad sections of code.  
* Common sections: CONSTANTS, SIGNALS, PUBLIC FUNCTIONS, PRIVATE FUNCTIONS.  
  \# PUBLIC FUNCTIONS  
  func start\_game(): \#\# Begins the main loop  
      pass

### **Function Bodies**

* **Minimalism:** Keep comments inside functions to an absolute minimum.  
* **Readability:** Rely on clear variable names and code structure rather than explaining what the code does line-by-line. Only comment complex logic that cannot be simplified.

### **BBCode and class reference inside documentation comments**

Godot's documentation comments class reference supports BBCode-like tags. They add nice formatting to the text which could be used in the documentation.

Please Note: 

\[kbd\] disables BBCode until the parser encounters \[/kbd\].

\[code\] disables BBCode until the parser encounters \[/code\].

\[codeblock\] disables BBCode until the parser encounters \[/codeblock\].

Warning \- Use \[codeblock\] for pre-formatted code blocks. Inside \[codeblock\], always use four spaces for indentation (the parser will delete tabs).

| Tag and Description | Example |
| :---- | :---- |
| \[Class\] Link to class | Move the \[Sprite2D\]. |
| \[annotation Class.name\] Link to annotation | See \[annotation @GDScript.@rpc\]. |
| \[constant Class.name\] Link to constant | See \[constant Color.RED\]. |
| \[enum Class.name\] Link to enum | See \[enum Mesh.ArrayType\]. |
| \[member Class.name\] Link to member (property) | Get \[member Node2D.scale\]. |
| \[method Class.name\] Link to method | Call \[method Node3D.hide\]. |
| \[constructor Class.name\] Link to built-in constructor | Use \[constructor Color.Color\]. |
| \[operator Class.name\] Link to built-in operator | Use \[operator Color.operator \*\]. |
| \[signal Class.name\] Link to signal | Emit \[signal Node.renamed\]. |
| \[theme\_item Class.name\] Link to theme item | See \[theme\_item Label.font\]. |
| \[param name\] Parameter name (as code) | Takes \[param size\] for the size. |
| \[br\] Line break | Line 1.\[br\] Line 2\. |
| \[lb\] \[rb\] \[ and \] respectively | \[lb\]b\[rb\]text\[lb\]/b\[rb\] |
| \[b\] \[/b\] Bold | Do \[b\]not\[/b\] call this method. |
| \[i\] \[/i\] Italic | Returns the \[i\]global\[/i\] position. |
| \[u\] \[/u\] Underline | \[u\]Always\[/u\] use this method. |
| \[s\] \[/s\] Strikethrough | \[s\]Outdated information.\[/s\] |
| \[color\] \[/color\] Color | \[color=red\]Error\!\[/color\] |
| \[font\] \[/font\] Font | \[font=res://mono.ttf\]LICENSE\[/font\] |
| \[img\] \[/img\] Image | \[img width=32\]res://icon.svg\[/img\] |
| \[url\] \[/url\] Hyperlink | \[url\]https://example.com\[/url\] \[url=https://example.com\]Website\[/url\] |
| \[center\] \[/center\] Horizontal centering | \[center\]2 \+ 2 \= 4\[/center\] |
| \[kbd\] \[/kbd\] Keyboard/mouse shortcut | Press \[kbd\]Ctrl \+ C\[/kbd\]. |
| \[code\] \[/code\] Inline code fragment | Returns \[code\]true\[/code\]. |
| \[codeblock\] \[/codeblock\] Multiline code block | See below. |

## 

## **2\. Naming Conventions**

Follow the standard Godot naming conventions to ensure compatibility with engine API and consistency.

| Type | Convention | Example |
| :---- | :---- | :---- |
| **File names** | snake\_case | weapon\_controller.gd |
| **Class names** | PascalCase | WeaponController |
| **Node names** | PascalCase | PlayerSprite, MainCamera |
| **Functions** | snake\_case | get\_target(), \_calculate\_velocity() |
| **Variables** | snake\_case | movement\_speed, \_current\_health |
| **Signals** | snake\_case (past tense) | door\_opened, health\_changed |
| **Constants** | CONSTANT\_CASE | MAX\_SPEED, DEFAULT\_gravity |
| **Enums** | PascalCase | enum State { IDLE, RUN } |

## **3\. Formatting**

### **Indentation & Whitespace**

* **Indentation:** Use **Tabs** (standard Godot default).  
* **Line Length:** Keep lines under 100 characters where possible.  
* **Spacing:**  
  * One space around operators: x \= y \+ 1  
  * No spaces inside parentheses: method(arg1, arg2)  
  * Two blank lines surrounding class/function definitions.  
  * One blank line to separate logical sections within functions (use sparingly).

### **Code Structure**

* **One statement per line:** Never use ; to combine lines.  
  * *Exception:* The ternary operator var x \= 5 if true else 2\.  
* **Parentheses:** Avoid unnecessary parentheses in if statements.  
  * **Good:** if is\_active and valid:  
  * **Bad:** if (is\_active && valid):

## **4\. Code Order**

Organize script elements in this order to maximize readability.

1. @tool, class\_name, extends  
2. **Script Documentation Block**  
3. \# SIGNALS  
4. \# ENUMS  
5. \# CONSTANTS  
6. \# EXPORT VARIABLES  
7. \# PUBLIC VARIABLES  
8. \# PRIVATE VARIABLES (\_onready vars go here)  
9. \# BUILT-IN VIRTUAL METHODS (\_init, \_ready, \_process)  
10. \# PUBLIC FUNCTIONS  
11. \# PRIVATE FUNCTIONS

## **5\. Static Typing**

Use static typing to improve performance and code safety.

* **Inferred Types:** Use := when the type is unambiguous.  
  var health := 100 \# Inferred as int  
  var velocity := Vector2.ZERO \# Inferred as Vector2

* **Explicit Types:** Use explicit typing when the value is not immediately clear or needs to be specific.  
  var health\_bar: ProgressBar \# Explicit is better for unassigned vars  
  func damage(amount: int) \-\> void: \# Always type function arguments and returns

## **6\. Complete Example**

Here is a script demonstrating all the rules above combined.

class\_name PlayerController  
extends CharacterBody2D  
\#\# Handles player movement, input, and state management.  
\#\#  
\#\# This script uses a simple state machine to manage movement.  
\#\# It handles physics processing internally but exposes signals  
\#\# for UI updates. Ensure the 'InputMap' is configured with  
\#\# 'move\_left', 'move\_right', and 'jump' actions.

\# SIGNALS  
signal health\_changed(new\_value) \#\# Emitted when health is modified  
signal died \#\# Emitted when health reaches 0

\# ENUMS  
enum State {  
    IDLE, \#\# Standing still  
    RUN, \#\# Moving on ground  
    AIR, \#\# Jumping or falling  
}

\# CONSTANTS  
const GRAVITY \= 980.0 \#\# World gravity applied per second

\# EXPORT VARIABLES  
@export var speed: float \= 300.0 \#\# Horizontal movement speed  
@export var jump\_force: float \= \-400.0 \#\# Upward force for jumping

\# PUBLIC VARIABLES  
var current\_state: State \= State.IDLE \#\# Current active state of the player

\# PRIVATE VARIABLES  
var \_health := 100  
@onready var \_sprite: Sprite2D \= $Sprite2D

\# BUILT-IN VIRTUAL METHODS  
func \_ready() \-\> void:  
    \_update\_animation()

func \_physics\_process(delta: float) \-\> void:  
    \_apply\_gravity(delta)  
    \_handle\_input()  
    move\_and\_slide()  
    \_check\_state\_changes()

\# PUBLIC FUNCTIONS  
func take\_damage(amount: int) \-\> void: \#\# Reduces health and handles death logic  
    \_health \-= amount  
    health\_changed.emit(\_health)  
      
    if \_health \<= 0:  
        died.emit()  
        queue\_free()

func heal(amount: int) \-\> void: \#\# Restores health up to max  
    \_health \+= amount   
    health\_changed.emit(\_health)

\# PRIVATE FUNCTIONS  
func \_apply\_gravity(delta: float) \-\> void: \# Applies gravity if not on floor  
    if not is\_on\_floor():  
        velocity.y \+= GRAVITY \* delta

func \_handle\_input() \-\> void: \# Reads input map and sets X velocity  
    var direction := Input.get\_axis("move\_left", "move\_right")  
    if direction:  
        velocity.x \= direction \* speed  
    else:  
        velocity.x \= move\_toward(velocity.x, 0, speed)

    if Input.is\_action\_just\_pressed("jump") and is\_on\_floor():  
        velocity.y \= jump\_force

func \_check\_state\_changes() \-\> void: \# Updates enum state based on motion  
    var new\_state := current\_state  
      
    if not is\_on\_floor():  
        new\_state \= State.AIR  
    elif velocity.x \!= 0:  
        new\_state \= State.RUN  
    else:  
        new\_state \= State.IDLE  
          
    if new\_state \!= current\_state:  
        current\_state \= new\_state  
        \_update\_animation()