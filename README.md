# Tether — Project Report

**CASA0021: Connected Environments** **Group Prototype and Pitch 25/26** **A connected cycling system for real-time ride awareness, social motivation, and emergency signaling** **Submitted as part of the Tether project documentation** **Group Four Gods (Group 4)** **Members:** Gilang Pamungkas · Haoyu Hu · Yidan Gao · Yifei Huang  
**GitHub:** [https://github.com/CrazyEpi/CASA0021-Tether](https://github.com/CrazyEpi/CASA0021-Tether)

---

## 1. Introduction
Tether is a connected cycling system comprising a mobile application and a handlebar-mounted ambient device. It responds to a structural incompatibility between attention-intensive smartphone interfaces and the embodied demands of cycling, externalising ride feedback into a bicycle-mounted ambient interface that enables real-time awareness of performance, social comparison, and safety state without requiring riders to disengage from their environment. This report documents the problem context, iterative design and development process, research positioning, production costs, sustainability, and future directions for the project.

## 2. Problem Context and Research Question
The proliferation of consumer cycling technology — principally smartphone applications such as Strava and Komoot — has significantly expanded access to ride tracking, route planning, and social comparison. However, these systems are designed around a screen-interaction paradigm that assumes sedentary or low-demand contexts. Cycling imposes simultaneous demands on motor control, environmental awareness, and spatial navigation, making sustained visual engagement with a handheld device both cognitively costly and physically hazardous (Strayer and Drews, 2007). Alternative hardware — dedicated cycling computers and smartwatches — partially mitigate smartphone dependency but replicate the same assumption: information density and direct visual engagement remain primary values, requiring deliberate focused reading that interrupts riding. This represents what Norman (2013) describes as a mismatch between the system's interaction model and the user's cognitive and physical context.

Beyond functional limitations, the social dimension of cycling is systematically underdeveloped in current platforms. Strava's social features are predominantly retrospective — kudos, segment comparisons, and activity feeds are experienced after the ride, not during it. This forecloses a class of motivational and affective interaction that could meaningfully support riders during the ride itself: awareness of a friend's concurrent progress, lightweight social presence, and shared goal pursuit (Consolvo et al., 2006).

Tether is situated within the research tradition of ubiquitous computing (Weiser, 1991) and calm technology (Weiser and Brown, 1996), which argue that the most valuable computational systems are those that recede into the periphery of attention, providing information as needed without demanding focal engagement. This tradition has informed ambient display research (Mankoff et al., 2003) and wearable computing (Gemperle et al., 1998), but has seen limited application to the specific context of cycling, where the case for peripheral, ambient feedback is especially compelling.

No existing consumer product or research prototype addresses this combination simultaneously: ambient cycling displays such as Beeline prioritise navigation over social feedback; social platforms such as Strava are retrospective and screen-dependent; and safety-focused wearables do not integrate ride awareness or motivation. This tripartite gap — ambient feedback, concurrent social presence, and physical emergency signalling — defines the design space that Tether occupies. The central research question is: how can a connected cycling system support real-time ride awareness, social motivation, and emergency signalling while minimising attentional disruption? Tether operationalises this through ambient LED feedback, a glanceable AMOLED display, and a Bluetooth Low Energy (BLE) communication layer between a handlebar-mounted device and a companion mobile application.

## 3. Target Users and Scenarios
Tether targets four distinct user groups in urban cycling contexts. Commuters need situational awareness — distance to destination, speed, connection status — without diverting attention from traffic. Fitness riders pursuing daily distance goals benefit from continuous progress feedback that motivates without demanding screen engagement. Socially connected cyclists riding simultaneously with friends gain shared awareness through the split-ring comparison without needing to message or call. Users with safety concerns — lone riders, night cyclists, or those in low-visibility conditions — benefit from a physical emergency trigger that works without unlocking a phone.

Three core scenarios structured the design process:
* **Individual riding:** A commuter sets a daily distance goal; the LED ring fills progressively as the goal is approached, supporting sustained behaviour change through continuous goal visibility.
* **Shared riding:** Two friends ride simultaneously; the split-ring mode shows each rider's progress in a separate arc, enabling social comparison without screen interaction. Awareness of a peer's concurrent effort draws on social facilitation principles to increase individual motivation.
* **Emergency context:** A three-second physical hold triggers an SOS alert routed via BLE to the app and onwards to the cloud. The hold duration is a deliberate design trade-off: long enough to prevent accidental activation, short enough to be operable under physical stress.

## 4. Design and Development

### 4.1 Hardware Prototyping Iterations

**Prototype 1** The first prototype was built with an Arduino MKR 1010 WiFi board, a NeoPixel LED strip, and an LC76G GPS module. Its main purpose was to verify the core concept: that GPS data could be translated into visual LED feedback. This prototype successfully demonstrated the basic interaction logic, but was assembled on a breadboard with Dupont connectors, making it too fragile and bulky for outdoor cycling. WiFi introduced unnecessary power consumption and latency, and GPS drift created errors of around 1.5 metres.  
*Figure 1. Prototype 1*

**Prototype 2** The second iteration migrated to an ESP32-S3 paired with a 1.75-inch AMOLED display, retaining the LC76G GPS and upgrading to a circular NeoPixel ring. The ring geometry was a deliberate design decision: a circular arc is readable as a proportional fill in a single glance, where a strip would require counting LEDs or parsing a numerical value. This prototype introduced speed display, GPS status feedback, and friend-count indication. However, GPS drift reached 15–20 metres in urban canyons, and battery capacity remained insufficient for rides exceeding 45 minutes.  
*Figure 2. Prototype 2*

**Current Prototype** The final hardware design addressed both residual issues. GPS computation and drift correction was fully offloaded to the mobile phone, which acts as the GPS and cloud gateway — a significant architectural decision that simplified the embedded firmware, reduced device power consumption, and improved positional accuracy by leveraging the phone's more powerful GPS chipset and drift-correction algorithms. The battery was upgraded to a 900mAh LiPo, and the assembly housed in a custom 3D-printed enclosure designed for handlebar mounting.  
*Figure 3. Current Prototype*

**How it Works** The ESP32-S3 acts as a smart display terminal rather than a computation unit. It establishes a BLE connection with the smartphone; the phone sends a processed data packet every second. The device refreshes its screen and controls the 24-LED NeoPixel ring accordingly: in single mode the ring fills blue to show goal progress; in friend mode it splits into two colours for comparative progress; in SOS mode the screen blinks red and alerts connected partners. Display brightness dims automatically at low speed to conserve battery.

### 4.2 Enclosure Design Iterations
The 3D-printed enclosure underwent four complete revision cycles. Early versions used fixed clips incompatible with different handlebar diameters; subsequent iterations introduced a rotary interlock and a friction-based screen locker after field testing showed the display rotating under vibration. The current version uses rubber band mounts for field adjustability. The light diffuser cover remains an acknowledged weak point — insufficient sealing causes light bleed between LED segments in high-ambient-light conditions.  
*Figure 4. 3D-printed enclosure*

### 4.3 Communication Architecture
Bluetooth Low Energy was chosen over WiFi for three reasons: power efficiency, near-zero latency for the SOS channel, and peer-to-peer operation without infrastructure dependency. The BLE service exposes six characteristics across a single service (UUID: 19B10000-E8F2-537E-4F6C-D104768A1214).

### 4.4 Mobile Application Development
The companion application was built in Flutter, enabling a single codebase for iOS and Android. It integrates three live data sources during a ride: phone GPS, BLE hardware telemetry, and real-time friend position data from Firebase Firestore (europe-west2 region). Firebase was chosen for its real-time synchronisation — Firestore's onSnapshot listener propagates a friend's updated distance to both the app and the handlebar device within seconds. Eight fully functional screens cover the full ride lifecycle from route planning through post-ride social feed.  
*Figure 5. Users register with email on the Profile page. In the app, they can set riding goals and view the live map. The device automatically shows progress. Live Tracking supports real-time ride monitoring, friend racing with synced distance display, and monthly ranking based on cycling mileage.*

### 4.5 Field Testing and Execution
Each prototype was driven by real-world riding findings. Prototype 1 could not be field tested due to absent battery power. Prototype 2 revealed three failures: GPS drift of 15–20 metres in urban canyons; battery range anxiety beyond 45 minutes; and display rotation under handlebar vibration, resolved by the screen locker in enclosure revision 3. The current prototype resolved positional accuracy by offloading GPS to the phone; BLE connection remained stable across all test rides. Remaining weaknesses are LED light bleed in direct sunlight and enclosure sealing, both identified as next-cycle priorities.

## 5. System Architecture
Tether operates as a three-layer system: the phone application layer handles GPS and cloud sync; the BLE transport layer transfers structured data packets; and the ESP32 device layer renders feedback via display and LED ring. The device implements three LED rendering modes:
* **Solo mode:** Single-colour arc proportional to rider's goal completion
* **Friend mode:** Split ring — blue for rider, purple for friend — enabling comparative progress at a glance
* **Emergency mode:** Full-ring red override superseding all other LED states

An adaptive brightness algorithm dims the display at low speed to conserve battery — a power management decision that emerged from field testing in Prototype 2.  
*Figure 6. Three-layer system architecture: phone application layer handles GPS and cloud sync; BLE transport layer transfers structured data packets; ESP32 device layer renders feedback via display and LED ring.* *Figure 7. Final prototype enclosure mounted on handlebars, showing the 1.75" AMOLED display and 24-LED NeoPixel ring and emergency model.* The project GitHub repository covers step-by-step hardware assembly, ESP32 firmware flashing, Flutter application deployment, and the full BLE characteristic table with UUID definitions and payload formats — enabling a reader to build and run Tether independently without reference to this report.

## 6. Research Context
Tether contributes to Connected Environments research on embedding computational feedback into physical activity contexts. Its core design principle — externalising information into an ambient peripheral interface — builds directly on Weiser and Brown's (1996) calm technology framework, which distinguishes technologies demanding focal attention from those operating at the periphery until needed.

The LED ring as an ambient display aligns with the ambient information systems literature (Mankoff et al., 2003; Pousman and Stasko, 2006), which characterises effective ambient displays as those achieving high information legibility at low attentional cost. Tether operationalises this through the arc-fill metaphor: progress is encoded spatially and proportionally, readable in a peripheral glance without numerical parsing.

The social comparison layer connects to persuasive technology and social fitness motivation research. Consolvo et al. (2006) demonstrated that real-time awareness of peers' activity significantly increased physical activity in field trials. Tether's split-ring friend mode applies this principle to concurrent cycling via Firebase-synchronised shared presence (Brave and Dahley, 1997). The three-second SOS hold pattern balances accidental trigger prevention against operability under stress — prioritising speed of activation in high-demand conditions.

## 7. Production Costs

### 7.1 Component Costs
The current prototype's direct component cost is £64.30 per unit. At mass production scale, with distribution (£10), employee cost (£15), marketing and research (£8), and cloud and operations (£8) factored in, the total cost per unit rises to £104.30. The suggested retail price of £149 positions Tether competitively against the Beeline Velo 2 (£99.99) while offering differentiated social and safety functionality:
* Breakeven point: ~17 months
* Year 1 target: 1,200 units
* Year 3 net profit: ~£367,400 (at 7,000 units)
* Subscription tier: £5/month for premium social features

### 7.2 Sustainability Considerations
BLE reduces device power consumption relative to WiFi, and offloading GPS to the phone eliminates a second chipset. The PLA enclosure is biodegradable under industrial composting conditions, though lack of modular disassembly limits end-of-life component recovery — a production version would allow the ESP32 and LED ring to be replaced independently. The LiPo battery carries the greatest environmental impact; a production version would partner with certified e-waste processors. Firebase runs on Google data centres committed to 24/7 carbon-free energy by 2030.

## 8. Competitive Positioning
Tether's closest commercial comparator is the Beeline Velo 2 (£99.99). Its competitive edge lies in social and safety differentiation within the same price bracket. Battery durability and weather resistance represent the primary hardware engineering priorities for a production version.

## 9. Future Work
Given additional time and resources, two development directions stand out as most impactful. The first is hardware independence: the current architecture's reliance on a paired phone for GPS and cloud connectivity limits standalone operation — if the phone battery dies or BLE range is exceeded, SOS alerts cannot be sent. This would require redesigning the power management layer and upgrading the enclosure to IP65 weather resistance with a gasket-sealed lid. The second is automatic crash detection: the ESP32-S3 already carries a QMI8658 six-axis IMU, and extending the firmware to monitor for impact signatures — a sudden high-g spike followed by near-zero motion — would enable automatic SOS triggering with a 10-second on-device cancellation window to prevent false positives.

## 10. Conclusion
Tether demonstrates a principled approach to ambient information delivery in high-demand physical activity contexts. Grounded in ubiquitous computing and calm technology theory, and validated through three hardware prototypes, four enclosure revisions, and real-world ride testing, the system meaningfully reduces smartphone dependency while introducing social and safety capabilities absent from existing commercial devices. The commercial model, sustainability analysis, and competitor benchmarking go beyond the immediate module scope. Current limitations in battery life, enclosure sealing, and weather resistance are engineering refinements rather than fundamental design flaws, and the core architecture — ambient feedback, phone-as-gateway, BLE safety signalling — provides a sound foundation for continued development.
