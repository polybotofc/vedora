import { useEffect, useState } from "react";
import { createUseStyles } from "react-jss";
import request, { getBaseUrl } from "../../lib/request";
import { adTypes } from "./constants";
import Link from "../link";

const useStyles = createUseStyles({
    adWrapper: {},
    adImage: {
        width: '100%',
        height: 'auto',
        margin: '0 auto',
        display: 'block',
        '@media(max-width: 800px)': {
            paddingTop: '10px',
            paddingBottom: '10px',
        },
    },
})

// /user-sponsorship/:type is counted as a view, so once-per-type is enough.
// Caching the in-flight promise also keeps React StrictMode's double-invoked
// effect (mount, unmount, remount) from firing two requests.
const adRequestCache = {};

const fetchAd = (type) => {
    if (!adRequestCache[type]) {
        adRequestCache[type] = request('GET', `${getBaseUrl()}/user-sponsorship/${type}`)
            .then(adData => adData.data)
            .catch(e => {
                // Allow a later mount to retry after a transient failure.
                delete adRequestCache[type];
                throw e;
            });
    }
    return adRequestCache[type];
};

/**
 * User advertisement iframe
 * @param {{type: number; wrapperClass?: string; backupWidth?: number;}} props
 */
const UserAdvertisement = props => {
    const info = adTypes[props.type];
    const [imageUrl, setImageUrl] = useState(null);
    const [link, setLink] = useState(null);
    const [title, setTitle] = useState(null);
    const [imageLoaded, setImageLoaded] = useState(false);
    const s = useStyles();

    useEffect(() => {
        let cancelled = false;
        fetchAd(props.type).then(data => {
            if (cancelled) return;
            // A missing or empty sponsorship response means the user simply has
            // no active ad; render the placeholder instead of logging an error.
            if (!data || typeof data !== 'string') {
                return;
            }
            let doc;
            try {
                doc = new DOMParser().parseFromString(data, 'text/html');
            } catch (e) {
                console.error('[error] could not parse user ad document:', e);
                return;
            }
            const imageElements = doc.getElementsByTagName('img');
            const aTags = doc.getElementsByTagName('a');
            // Same as above: no `<img>`/`<a>` is a valid "no ad" response, not a
            // failure. Only the render below depends on these elements.
            if (!imageElements.length || !aTags.length) {
                return;
            }
            const imageUrl = imageElements[0].getAttribute('src');
            const link = aTags[0].getAttribute('href');
            const adTitle = aTags[0].getAttribute('title');
            if (!imageUrl || !link || !adTitle) {
                console.error('[error] could not get an attribute from iframe: ', imageUrl, link, adTitle);
                return;
            }
            setImageUrl(imageUrl);
            setTitle(adTitle);
            setLink(link);
        }).catch(e => {
            console.error('[error] could not load user ad:', e);
        });

        return () => {
            cancelled = true;
        };
    }, [props.type]);
    
    // TODO: calculate correct height of ad when current screen width is smaller than ad width. The height is way too big on mobile.
    if (!info) throw new Error(`unexpected adType: ${props.type}`);
    if (!imageUrl) {
        return <div className={`${props?.wrapperClass || ''}`} style={{ width: props.backupWidth || '100%', height: info.height }}/>
    }
    return <div className={`${s.adWrapper} ${props?.wrapperClass || ''}`}
                style={imageLoaded ? undefined : { height: info.height, width: '100%' }}>
        <Link href={link || '#'}>
            <a title={title}>
                <img onLoad={() => {
                    setImageLoaded(true)
                }} src={imageUrl} className={s.adImage} style={{ maxWidth: info.width, maxHeight: info.height }}/>
            </a>
        </Link>
    </div>
}

export default UserAdvertisement;