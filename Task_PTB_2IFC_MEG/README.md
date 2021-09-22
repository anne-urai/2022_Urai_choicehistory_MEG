# 2IFC_RDK_MEG
==========================================================

Scripts are supposed to be used in the order of their numbering. s1a and s1b are examples to run at their first visit (make sure that s1b is done with about 10 trials at 0.3 threshold first, then at 0.2 and then at 0.15, until they get the hang of it). Then, run s2 (5 blocks method of constants thresholding), and follow up with s2b which runs a short staircase (2-up 1-down) to see how stable this threshold is.

s3 is used in the MEG for a 5 minute resting state session, to be done before each of their MEG sessions. s4_Main is the real script in which they do the task - this one can be set to either MEG or training, and will take the right config depending on the room where you're testing. s5 measures the individual pupil IRF and should be run in the MEG (since that's where the eyetracker is). Might as well record some MEG during this too!

Get in touch if you have questions about HLoc (the vswitch command is the key here), trigger sending (see setupTrig), or Eyelink config (make sure to use the ELconfig here, since it makes sure eyelink recognizes the mirrored display in the MEG (because of video projection from behind rather than screen in front).

==========================================================
UKE SPECIFICS AND HOW-TO CHECKLIST

(Protocol for Anne's Pharma + MEG + Eyetracking + learning study)
==========================================================


Entering the lab
* Type in code at the main door (ask me for it), hold dongle and press the O button to unlock the alarm, then unlock the door 2x

Setting up
* Left of the MEG chamber:
	- Turn on beamer, red button on the side
	- Turn on Audio system and follow the instruction set written on there
	- Buttonbox (on top): Change mode - manual - HHSC 2x2 - USB - HID key 12345
	- Turn off the power supply of the audio system, so that it runs on battery during measurements - avoid 50Hz line noise. Make sure to turn back on afterwards!
* Inside MEG chamber:
	- on the right of the scanner on the floor, turn audiobox button to lowest position for sound (see mark)
	- To reduce powerline-noise to lowest possible values disconnect the powersupply (*1in Pic) during the measurement. Don't forget to reconnect at the end of Your measurements!
	- Check if the audio tubes are properly inserted on both sides – otherwise, no sound there!
* Experimenter controls
	- Turn on screens for acquisition 2x, monitor, head localization, stim 2x, intercom
	- On stim PC, start into Windows, username Urai
	- if using the Eyetracker, use MATLAB32 on the desktop
	- to disable the taskbar (which annoyingly pops up during PTB window), cancel explorer.exe in task manager
	- make sure the monitors are mirrored, PTB doesn't work well in dual-display mode under Windows 7
	- vswitch(00), see Roger's manual
	- Anzeige anstellungen: set monitor to 1280x1024 @ 60 Hz
* To check helium levels; put in probe in the wall in MEG room and switch on the meter on the right of the acquisition computer - below 2% becomes a problem

Pharma and medical checks for the subject
* First session: Let them fill out and sign the Einwilligerserklärung with all the medical info we need
	- Measure heart rate and blood pressure: machine is behind the stimulus PC in a box. Put around the left upper arm, cable on the elbow side, and simply press the button
	- Write the values down on the form for this subject
	- If not < 120/80 mm or heart rate > 75, wait before giving pharma
	- Give them the drug, note down the time
	- 1.5hrs after first drug: heartrate + blood pressure measurements, give the other pharma
	- 30 mins before MEG session start: tell them to go to the bathroom, put on MEG compatible clothes, remove any remaining metal
	- MEG session/training (see below)

Preparing the subject
* Standard electrode layout: 4 EOG, EKG, reference on forehead, ground on forearm, radial EOG (4 cm above inion to get a saccade signal)
* Position them in the MEG
* See Messbuch: plug physiological channels in
* Coils in ears (S/M/L size ear plugs) and above the nose
* Turn the chair up with the turning knob on left bottom
* Hang wooden footrest so that they don't move downwards, possibly pillows or blankets?
* Place table with EyeLink camera in front – screen should be 65cm from eyes, eyelink in front
* Turn on the script on Matlab
* When they sit, place the mirror so that the squares are aligned with the screen corners (see psychtoolbox code)
	- properly position screen, mirror and sharpen the beamer manually if needed

Running the experiment
* First make sure they are well-positioned and start resting-state scan for about 5 mins
	- this will make them sit in a comfy position, afterwards can put them higher again
* Then start real psychtoolbox code
	- On the computer on the right, start ACQ for data acquisition
	- Load in protocol for this study DotsPL.rd (if you don�t have a protocol, make one with Gerard Steinmetz)
	- Measure head position, wait a bit and check that they are comfy
	- Calibrate the EyeLink (call from PsychToolbox code, see code by Hannah)
* After a block, they will see the head localization screen from FieldTrip so they can reposition themselves in the MEG (can also talk to them)
	- 10 blocks of 60 trials

Closing
* Clean up electrodes, after taking them off put them in the grey box with water and then take them out to dry
	- Copy data
	- data is at /exportctfmeg/data/meg/ACQ_Data
	- 'scp -r filename username@node002:/home/aurai/Data', these files will be transferred to your account on the cluster
	- After copying all the data, sign the form Studienprotokoll; this means other people can delete your files!
	- Also sign off in the Messbuch that your session is finished
	- Data on the stim PC; don't directly put a USB stick in there, but transfer to STIM-CORE on the network and get it out from the computer in Christiane's room
* Turn off all the screens, stim and acquisition computers can stay on
* make sure to plug the power supply for the audio back in
* When leaving, lock all doors twice, check that all red lights at the entrance are off. Push the Red button next to the door, wait for ten seconds until the alarm goes off again and lock the front door from the outside. Then press I, hold the dongle and press I again: when locking, the alarm makes a noise for a few 
