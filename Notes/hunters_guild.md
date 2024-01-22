Options

1. Inject scene at welcome message, potentially others

Challenge with this is that the normal dialog routine is not used.
RunText is called directly, in order to manage the windows separately.
So, if we had any events (i.e. anything not in dialog loop),
we would break this.

Solutions?

a. Don't use non-dialog events! - in this case, just inject the dialog (option 2)
b. Allow non-dialog events, but add some logic to use accommodate the different dialog routine. The main thing is that the window is just left open after RunText is invoked, so that the job list can display concurrently. So technically we'd only need special handling for the end of the routine (don't close the dialog window).
c. Allow non-dialog events, but just accept that the scene will end with the dialog window closing, and we'll have separate assembly for the dialog while the window is open.

2. Output only dialog ids, use those at build time

- For each dialog section, output dialog IDs for the map.
- In the assembly, refer to these as constants
- Generate hunters guild data (HuntersGuildData), referring to flags and dialog ids for jobs, as well as money table and quest titles
- During generation, we should check that these scenes don't produce event code. Basically, run the scene generator without starting an event routine, and this should handle it. **We can check ahead of time if the scene requires an event and fail gracefully in that case.**

3. Replace the whole scene and use raw ASM techs to implement job menu and sequences

This might do weird things with the job selection?
