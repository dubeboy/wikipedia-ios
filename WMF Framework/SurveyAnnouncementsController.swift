
import Foundation

@objc(WMFSurveyAnnouncementsController)
public final class SurveyAnnouncementsController: NSObject {
    
    @objc public static let shared = SurveyAnnouncementsController()
    
    private let queue = DispatchQueue(label: "SurveyAnnouncementsQueue")
    
    private var _announcements: [WMFAnnouncement] = []
    @objc public var announcements: [WMFAnnouncement] {
        get {
            return queue.sync { _announcements }
        }
        set {
            queue.sync {
                _announcements = newValue.filter { $0.announcementType == .survey }
            }
        }
    }
    
    private override init() {
        super.init()
    }
    
    public struct SurveyAnnouncementResult {
        public let campaignIdentifier: String
        public let announcement: WMFAnnouncement
        public let actionURL: URL
        public let displayDelay: TimeInterval
    }
    
    //Use for determining whether to show user a survey prompt or not.
    //Considers domain, campaign start/end dates, article title in campaign, and whether survey has already been acted upon or not.
    public func activeSurveyAnnouncementResultForTitle(_ articleTitle: String, siteURL: URL) -> SurveyAnnouncementResult? {

        for announcement in announcements {
            
            guard let startTime = announcement.startTime,
                let endTime = announcement.endTime,
                let domain = announcement.domain,
                let articleTitles = announcement.articleTitles,
                let displayDelay = announcement.displayDelay,
                let components = URLComponents(url: siteURL, resolvingAgainstBaseURL: false),
                let host = components.host,
                let identifier = announcement.identifier,
                let normalizedArticleTitle = articleTitle.normalizedPageTitle else {
                    continue
            }
            
            let googleFormattedArticleTitle = normalizedArticleTitle.replacingOccurrences(of: " ", with: "+")
            
            guard let actionURL = announcement.actionURLReplacingPlaceholder("{{articleTitle}}", withValue: googleFormattedArticleTitle) else {
                continue
            }
                
            let now = Date()
            
            //do not show if user has already seen and answered for this campaign
            guard UserDefaults.standard.object(forKey: identifier) == nil else {
                continue
            }
            
            //ignore startTime/endTime and reduce displayDelay for easier debug testing
            #if DEBUG
                
                if host == domain, articleTitles.contains(normalizedArticleTitle) {
                    
                    return SurveyAnnouncementResult(campaignIdentifier: identifier, announcement: announcement, actionURL: actionURL, displayDelay: 10.0)
                    
                }
            
            #else
            
                if now > startTime && now < endTime && host == domain, articleTitles.contains(normalizedArticleTitle) {
                    return SurveyAnnouncementResult(campaignIdentifier: identifier, announcement: announcement, actionURL: actionURL, displayDelay: displayDelay.doubleValue)
                }
            
            #endif
        }
        
        return nil
    }
    
    public func markSurveyAnnouncementAnswer(_ answer: Bool, campaignIdentifier: String) {
        UserDefaults.standard.setValue(answer, forKey: campaignIdentifier)
    }
}
