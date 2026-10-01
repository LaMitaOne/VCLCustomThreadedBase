# VCLCustomThreadedBase
A high-performance, threaded Delphi VCL component that utilizes pure GDI for off-screen rendering without blocking the UI thread.
    
VCLCustomThreadedBase v1.0    
     
[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/LaMitaOne/VCLCustomThreadedBase)    
          
<img width="800" height="632" alt="Unbenannt" src="https://github.com/user-attachments/assets/d15524aa-b56b-47f7-a79a-e1902a5133a4" />
              
yes really 937+ fps max i get here on a Ryzen 4500U using pure GDI. The mother of all threaded bases. On this one i played around a few months, and now its...in everything i make almost basically. So thought maybe someone wants the VCL version pure too.       
     
This base class provides a robust, drop-in architecture for running tight rendering and logic loops entirely in the background. Proven over months in production environments (powering components like Flowmotion with 1500+ simultaneously animated images), it is the ultimate foundation for VCL applications requiring high-throughput visualizations, custom controls, or interactive tools without freezing the main thread.    
    
Key Features:    
    
     Threaded Architecture: Separates the entire Logic and Render loop from the VCL UI thread. The main application remains 100% responsive, even under heavy rendering loads.
     Flowmotion-Proven Core: Utilizes the rock-solid TAnimationThread architecture combined with safe PostMessage communication, ensuring no deadlocks, no UI blocking, and no unstable TThread.Queue calls.
     Precise QPC Frame Pacing: Utilizes QueryPerformanceCounter (via TStopwatch) to calculate absolute frame deadlines. 
     Hybrid Sleep/SpinWait: Uses a two-phase wait strategy (WaitForSingleObject for the bulk of the frame, busy-spin the last ~2ms) to guarantee frame-exact timing without burning unnecessary CPU cycles.
     V-Sync Independent: Because we render directly to GDI, we are not bound by graphics API V-Sync limits. The loop can hit extreme FPS targets (900+ FPS) when VCL overhead is minimized.
     Zero-Flicker GDI: Explicitly enables VCL DoubleBuffered to buffer GDI Canvas commands off-screen and push them instantly, killing the classic Windows GDI flicker while maintaining extreme performance.
     Delta Time Updates: Logic updates use real measured delta times with safety clamping (prevents huge jumps after debugger pauses or window drags).
     Drift Correction: If the loop falls behind, it resyncs to "now" instead of rushing a burst of frames to catch up, maintaining a smooth visual experience.
     Virtual Architecture: Exposes UpdateLogic and RenderEffect as virtual methods, allowing you to easily derive custom components and inject your own math/physics and Canvas drawing code.
    
Sample Included    
     
The repository includes a sample project demonstrating a fully mathematically calculated 3D wireframe cube flying around in 3D space, proving that even pure GDI can achieve smooth, high-FPS animations when threaded correctly.
