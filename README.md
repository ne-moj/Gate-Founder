# Gate Founder

**Features:**
* Allows players and alliances to create warp gates. Type following command to know founding price: `/foundgate x y`
Then repeat with with "confirm" in the end to pay credits and found a gate: `/foundgate x y confirm`
* Fixes the issue of gates passing through other gates.

**Configuration:**

Using config file you may adjust founding price. It is being calculated with this formula:

![formula](https://i.ibb.co/LYM8fFn/formula.png)
* n - the number of gate player/alliance creates.
* passage - gate passage fee when relations are neutral (0).
* base - BasePriceMultiplier (default: 1500).
* multiplier - SubsequentGatePriceMultiplier (default: 1.1).
* power - SubsequentGatePricePower (default: 1.01).
