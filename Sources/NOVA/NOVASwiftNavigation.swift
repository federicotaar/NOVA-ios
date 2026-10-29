import SwiftUI
import UIKit

@MainActor struct NOVASwiftNavigation:UIViewRepresentable {
    @Binding var selected:Int
    let avatar:String
    func makeCoordinator()->Coordinator{Coordinator(self)}
    #if DEBUG
    static var forceLegacyFallback=false
    static var legacyPlainStyle=false
    #endif
    func makeUIView(context:Context)->UIView{
#if DEBUG
if NOVASwiftNavigation.forceLegacyFallback{return makeLegacyNavigation(context)}
#endif
if #available(iOS 26.0,*){let container=UIView();let surface=NativeLensSegments(items:[]);surface.accessibilityIdentifier="swiftOwnedNavigation";let backdrop=UIVisualEffectView(effect:UIGlassEffect(style:.regular));backdrop.cornerConfiguration = .capsule();backdrop.isUserInteractionEnabled=false;backdrop.translatesAutoresizingMaskIntoConstraints=false;surface.translatesAutoresizingMaskIntoConstraints=false;container.addSubview(backdrop);container.addSubview(surface);NSLayoutConstraint.activate([surface.leadingAnchor.constraint(equalTo:container.leadingAnchor),surface.trailingAnchor.constraint(equalTo:container.trailingAnchor),surface.topAnchor.constraint(equalTo:container.topAnchor),surface.bottomAnchor.constraint(equalTo:container.bottomAnchor),backdrop.leadingAnchor.constraint(equalTo:container.leadingAnchor),backdrop.trailingAnchor.constraint(equalTo:container.trailingAnchor),backdrop.topAnchor.constraint(equalTo:container.topAnchor),backdrop.bottomAnchor.constraint(equalTo:container.bottomAnchor)]);context.coordinator.surface=surface;configure(surface,context.coordinator);return container}else{return makeLegacyNavigation(context)}}
    // Pre-iOS 26 has no UIGlassEffect; the fallback keeps the capsule language with a frosted blur instead of a bare segmented control.
    private func makeLegacyNavigation(_ context:Context)->UIView{
#if DEBUG
if NOVASwiftNavigation.legacyPlainStyle{let surface=UISegmentedControl(items:[]);surface.accessibilityIdentifier="swiftOwnedNavigation";context.coordinator.surface=surface;configure(surface,context.coordinator);return surface}
#endif
let container=NOVASwiftLegacyNavContainer();let backdrop=UIVisualEffectView(effect:UIBlurEffect(style:.systemMaterial));backdrop.isUserInteractionEnabled=false;backdrop.translatesAutoresizingMaskIntoConstraints=false
let surface=UISegmentedControl(items:[]);surface.accessibilityIdentifier="swiftOwnedNavigation";surface.translatesAutoresizingMaskIntoConstraints=false;surface.backgroundColor = .clear
surface.setBackgroundImage(UIImage(),for:.normal,barMetrics:.default);surface.setBackgroundImage(UIImage(),for:.selected,barMetrics:.default);surface.setBackgroundImage(UIImage(),for:.highlighted,barMetrics:.default)
surface.setDividerImage(UIImage(),forLeftSegmentState:.normal,rightSegmentState:.normal,barMetrics:.default)
surface.selectedSegmentTintColor = UIColor{trait in trait.userInterfaceStyle == .dark ? UIColor.white.withAlphaComponent(0.22):UIColor.black.withAlphaComponent(0.10)}
container.addSubview(backdrop);container.addSubview(surface)
NSLayoutConstraint.activate([backdrop.leadingAnchor.constraint(equalTo:container.leadingAnchor),backdrop.trailingAnchor.constraint(equalTo:container.trailingAnchor),backdrop.topAnchor.constraint(equalTo:container.topAnchor),backdrop.bottomAnchor.constraint(equalTo:container.bottomAnchor),surface.leadingAnchor.constraint(equalTo:container.leadingAnchor),surface.trailingAnchor.constraint(equalTo:container.trailingAnchor),surface.topAnchor.constraint(equalTo:container.topAnchor),surface.bottomAnchor.constraint(equalTo:container.bottomAnchor)])
context.coordinator.surface=surface;configure(surface,context.coordinator);return container}
    private func configure(_ surface:UISegmentedControl,_ coordinator:Coordinator){for (index,symbol) in ["house","chart.bar","bubble.left.and.bubble.right","map","person.crop.circle"].enumerated(){surface.insertSegment(with:UIImage(systemName:symbol),at:index,animated:false)};surface.selectedSegmentIndex=selected;surface.addTarget(coordinator,action:#selector(Coordinator.changed),for:.valueChanged);if #available(iOS 26.0,*),let lens=surface as? NativeLensSegments{lens.trackingEvent={phase,x in
#if DEBUG
NotificationCenter.default.post(name:Notification.Name("NOVASwiftNavigationTracking"),object:nil,userInfo:["phase":phase])
#endif
if phase=="start"{coordinator.start=coordinator.parent.selected;coordinator.tracking=true};if phase=="end"{let width=max(1,lens.bounds.width);lens.selectedSegmentIndex=max(0,min(4,Int(x/(width/5))));coordinator.tracking=false;coordinator.finish()};if phase=="cancel"{coordinator.tracking=false;lens.selectedSegmentIndex=coordinator.start}};let observer=UILongPressGestureRecognizer(target:coordinator,action:#selector(Coordinator.observeDrag(_:)));observer.minimumPressDuration=0;observer.allowableMovement=10000;observer.cancelsTouchesInView=false;observer.delaysTouchesBegan=false;observer.delaysTouchesEnded=false;observer.delegate=coordinator;surface.addGestureRecognizer(observer)};surface.accessibilityLabel="Navigazione: Home, Voti, Chat, Mappa, Profilo";surface.setContentPositionAdjustment(UIOffset(horizontal:0,vertical:0),forSegmentType:.any,barMetrics:.default)}
    func updateUIView(_ view:UIView,context:Context){context.coordinator.parent=self;guard let surface=context.coordinator.surface else{return};if !surface.isTracking,!context.coordinator.tracking{surface.selectedSegmentIndex=selected};if avatar.count<=160000,avatar.hasPrefix("data:image/"),let value=avatar.split(separator:",",maxSplits:1).last,let data=Data(base64Encoded:String(value)),let image=UIImage(data:data){let icon=UIGraphicsImageRenderer(size:CGSize(width:26,height:26)).image{_ in UIBezierPath(ovalIn:CGRect(x:0,y:0,width:26,height:26)).addClip();image.draw(in:CGRect(x:0,y:0,width:26,height:26))};surface.setImage(icon.withRenderingMode(.alwaysOriginal),forSegmentAt:4)}else{surface.setImage(UIImage(systemName:"person.crop.circle"),forSegmentAt:4)}}
    @MainActor final class Coordinator:NSObject,UIGestureRecognizerDelegate{var parent:NOVASwiftNavigation;weak var surface:UISegmentedControl?;var start=0;var tracking=false;init(_ parent:NOVASwiftNavigation){self.parent=parent};func finish(){guard let surface=surface,(0...4).contains(surface.selectedSegmentIndex) else{return};parent.selected=surface.selectedSegmentIndex};func gestureRecognizer(_ gestureRecognizer:UIGestureRecognizer,shouldRecognizeSimultaneouslyWith otherGestureRecognizer:UIGestureRecognizer)->Bool{true};@objc func observeDrag(_ gesture:UILongPressGestureRecognizer){guard #available(iOS 26.0,*),let surface=surface as? NativeLensSegments else{return};let phase:String;switch gesture.state{case .began:phase="start";case .changed:phase="move";case .ended:phase="end";case .cancelled,.failed:phase="cancel";default:return};surface.trackingEvent?(phase,gesture.location(in:surface).x)};@objc func changed(){if !tracking,surface?.isTracking != true{finish()}}}
}
struct NOVASwiftComposerSurface:ViewModifier {
    func body(content:Content)->some View{if #available(iOS 26.0,*){content.padding(12).glassEffect(.regular.interactive(),in:.capsule)}else{content.padding(12).background(.regularMaterial,in:Capsule())}}
}

// The assistant uses a slim field and a separate attachment control, not one large capsule.
struct NOVASwiftAssistantGlass:ViewModifier {
    let circle:Bool
    @Environment(\.colorScheme) private var colorScheme
    @ViewBuilder func body(content:Content)->some View {
        if #available(iOS 26.0,*){
            if circle{content.glassEffect(.clear.interactive(),in:.circle)}else{content.glassEffect(.clear.interactive(),in:.rect(cornerRadius:22))}
        }else{
            if circle{content.background(.regularMaterial,in:Circle())}else{content.background(.regularMaterial,in:RoundedRectangle(cornerRadius:22))}
        }
    }
}

// Nearby native glass controls share one sampling region without merging shapes.
struct NOVASwiftComposerGlassGroup:ViewModifier {
    var composerBoundary=false
    @Environment(\.colorScheme) private var colorScheme
    @ViewBuilder func body(content:Content)->some View {
        if #available(iOS 26.0,*){GlassEffectContainer(spacing:0){content}.overlay {
            if composerBoundary && colorScheme == .light {
                HStack(alignment:.bottom,spacing:10){
                    Circle().strokeBorder(.black.opacity(0.20),lineWidth:1).frame(width:44,height:44)
                    RoundedRectangle(cornerRadius:22).strokeBorder(.black.opacity(0.20),lineWidth:1)
                }.allowsHitTesting(false).accessibilityHidden(true)
            }
        }}else{content}
    }
}

struct NOVASwiftComposerTextShadow:ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    func body(content:Content)->some View {content.shadow(color:colorScheme == .dark ? .black.opacity(0.85):.clear,radius:colorScheme == .dark ? 2:0,x:0,y:colorScheme == .dark ? 1:0)}
}

// Frosted capsule used by the pre-iOS 26 navigation fallback.
@MainActor final class NOVASwiftLegacyNavContainer:UIView {
    override func layoutSubviews(){super.layoutSubviews();layer.cornerRadius=bounds.height/2;layer.cornerCurve = .continuous;layer.masksToBounds=true;layer.borderWidth=0.5;layer.borderColor=UIColor.separator.withAlphaComponent(0.5).cgColor}
    override func traitCollectionDidChange(_ previous:UITraitCollection?){super.traitCollectionDidChange(previous);layer.borderColor=UIColor.separator.withAlphaComponent(0.5).cgColor}
}
