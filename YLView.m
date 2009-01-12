//
//  YLView.m
//  MacBlueTelnet
//
//  Created by Yung-Luen Lan on 2006/6/9.
//  Copyright 2006 yllan.org. All rights reserved.
//

#import "YLView.h"
#import "YLTerminal.h"
#import "YLConnection.h"
#import "YLSite.h"
#import "YLLGLobalConfig.h"
#import "YLMarkedTextView.h"
#import "YLContextualMenuManager.h"
#import "XIPreviewController.h"
#import "XIPortal.h"
#import "XIIntegerArray.h"
#import "IPSeeker.h"
#import "KOEffectView.h"
#import "KOTrackingRectData.h"
#import "KOMenuItem.h"
#include "encoding.h"
#include <math.h>


static YLLGlobalConfig *gConfig;
static int gRow;
static int gColumn;
static NSImage *gLeftImage;
static CGSize *gSingleAdvance;
static CGSize *gDoubleAdvance;
static NSCursor *gMoveCursor = nil;

NSString *ANSIColorPBoardType = @"ANSIColorPBoardType";

static NSRect gSymbolBlackSquareRect;
static NSRect gSymbolBlackSquareRect1;
static NSRect gSymbolBlackSquareRect2;
static NSRect gSymbolLowerBlockRect[8];
static NSRect gSymbolLowerBlockRect1[8];
static NSRect gSymbolLowerBlockRect2[8];
static NSRect gSymbolLeftBlockRect[7];
static NSRect gSymbolLeftBlockRect1[7];
static NSRect gSymbolLeftBlockRect2[7];
static NSBezierPath *gSymbolTrianglePath[4];
static NSBezierPath *gSymbolTrianglePath1[4];
static NSBezierPath *gSymbolTrianglePath2[4];

BOOL isEnglishNumberAlphabet(unsigned char c) {
    return ('0' <= c && c <= '9') || ('A' <= c && c <= 'Z') || ('a' <= c && c <= 'z') || (c == '-') || (c == '_') || (c == '.');
}

BOOL isSpecialSymbol(unichar ch) {
	if (ch == 0x25FC)  // ◼ BLACK SQUARE
		return YES;
	if (ch >= 0x2581 && ch <= 0x2588) // BLOCK ▁▂▃▄▅▆▇█
		return YES;
	if (ch >= 0x2589 && ch <= 0x258F) // BLOCK ▉▊▋▌▍▎▏
		return YES;
	if (ch >= 0x25E2 && ch <= 0x25E5) // TRIANGLE ◢◣◤◥
		return YES;
	return NO;
}

@interface YLView ()
- (void) drawSpecialSymbol:(unichar)ch forRow:(int)r column:(int)c leftAttribute:(attribute)attr1 rightAttribute:(attribute)attr2;
@end

@implementation YLView

+ (void) initialize {
    NSImage *cursorImage = [[NSImage alloc] initWithSize: NSMakeSize(11.0, 20.0)];
    [cursorImage lockFocus];
    [[NSColor clearColor] set];
    NSRectFill(NSMakeRect(0, 0, 11, 20));
    [[NSColor whiteColor] set];
    NSBezierPath *path = [NSBezierPath bezierPath];
    [path setLineCapStyle: NSRoundLineCapStyle];
    [path moveToPoint: NSMakePoint(1.5, 1.5)];
    [path lineToPoint: NSMakePoint(2.5, 1.5)];
    [path lineToPoint: NSMakePoint(5.5, 4.5)];
    [path lineToPoint: NSMakePoint(8.5, 1.5)];
    [path lineToPoint: NSMakePoint(9.5, 1.5)];
    [path moveToPoint: NSMakePoint(5.5, 4.5)];
    [path lineToPoint: NSMakePoint(5.5, 15.5)];
    [path lineToPoint: NSMakePoint(2.5, 18.5)];
    [path lineToPoint: NSMakePoint(1.5, 18.5)];
    [path moveToPoint: NSMakePoint(5.5, 15.5)];
    [path lineToPoint: NSMakePoint(8.5, 18.5)];
    [path lineToPoint: NSMakePoint(9.5, 18.5)];
    [path moveToPoint: NSMakePoint(3.5, 9.5)];
    [path lineToPoint: NSMakePoint(7.5, 9.5)];
    [path setLineWidth: 3];
    [path stroke];
    [path setLineWidth: 1];
    [[NSColor blackColor] set];
    [path stroke];
    [cursorImage unlockFocus];
    gMoveCursor = [[NSCursor alloc] initWithImage: cursorImage hotSpot: NSMakePoint(5.5, 9.5)];
    [cursorImage release];
}

- (NSRect) rectAtRow: (int)r 
			  column: (int)c 
			  height: (int)h 
			   width: (int)w {
	return NSMakeRect(c * _fontWidth, (gRow - h - r) * _fontHeight, _fontWidth * w, _fontHeight * h);
}

- (void) createSymbolPath {
	int i = 0;
	gSymbolBlackSquareRect = NSMakeRect(1.0, 1.0, _fontWidth * 2 - 2, _fontHeight - 2);
	gSymbolBlackSquareRect1 = NSMakeRect(1.0, 1.0, _fontWidth - 1, _fontHeight - 2); 
	gSymbolBlackSquareRect2 = NSMakeRect(_fontWidth, 1.0, _fontWidth - 1, _fontHeight - 2);
	
	for (i = 0; i < 8; i++) {
		gSymbolLowerBlockRect[i] = NSMakeRect(0.0, 0.0, _fontWidth * 2, _fontHeight * (i + 1) / 8);
        gSymbolLowerBlockRect1[i] = NSMakeRect(0.0, 0.0, _fontWidth, _fontHeight * (i + 1) / 8);
        gSymbolLowerBlockRect2[i] = NSMakeRect(_fontWidth, 0.0, _fontWidth, _fontHeight * (i + 1) / 8);
	}
    
    for (i = 0; i < 7; i++) {
        gSymbolLeftBlockRect[i] = NSMakeRect(0.0, 0.0, _fontWidth * (7 - i) / 4, _fontHeight);
        gSymbolLeftBlockRect1[i] = NSMakeRect(0.0, 0.0, (7 - i >= 4) ? _fontWidth : (_fontWidth * (7 - i) / 4), _fontHeight);
        gSymbolLeftBlockRect2[i] = NSMakeRect(_fontWidth, 0.0, (7 - i <= 4) ? 0.0 : (_fontWidth * (3 - i) / 4), _fontHeight);
    }
    
    NSPoint pts[6] = {
        NSMakePoint(_fontWidth, 0.0),
        NSMakePoint(0.0, 0.0),
        NSMakePoint(0.0, _fontHeight),
        NSMakePoint(_fontWidth, _fontHeight),
        NSMakePoint(_fontWidth * 2, _fontHeight),
        NSMakePoint(_fontWidth * 2, 0.0),
    };
    int triangleIndex[4][3] = { {1, 4, 5}, {1, 2, 5}, {1, 2, 4}, {2, 4, 5} };

    int triangleIndex1[4][3] = { {0, 1, -1}, {0, 1, 2}, {1, 2, 3}, {2, 3, -1} };
    int triangleIndex2[4][3] = { {4, 5, 0}, {5, 0, -1}, {3, 4, -1}, {3, 4, 5} };
    
    int base = 0;
    for (base = 0; base < 4; base++) {
        if (gSymbolTrianglePath[base]) 
            [gSymbolTrianglePath[base] release];
        gSymbolTrianglePath[base] = [[NSBezierPath alloc] init];
        [gSymbolTrianglePath[base] moveToPoint: pts[triangleIndex[base][0]]];
        for (i = 1; i < 3; i ++)
            [gSymbolTrianglePath[base] lineToPoint: pts[triangleIndex[base][i]]];
        [gSymbolTrianglePath[base] closePath];
        
        if (gSymbolTrianglePath1[base])
            [gSymbolTrianglePath1[base] release];
        gSymbolTrianglePath1[base] = [[NSBezierPath alloc] init];
        [gSymbolTrianglePath1[base] moveToPoint: NSMakePoint(_fontWidth, _fontHeight / 2)];
        for (i = 0; i < 3 && triangleIndex1[base][i] >= 0; i++)
            [gSymbolTrianglePath1[base] lineToPoint: pts[triangleIndex1[base][i]]];
        [gSymbolTrianglePath1[base] closePath];
        
        if (gSymbolTrianglePath2[base])
            [gSymbolTrianglePath2[base] release];
        gSymbolTrianglePath2[base] = [[NSBezierPath alloc] init];
        [gSymbolTrianglePath2[base] moveToPoint: NSMakePoint(_fontWidth, _fontHeight / 2)];
        for (i = 0; i < 3 && triangleIndex2[base][i] >= 0; i++)
            [gSymbolTrianglePath2[base] lineToPoint: pts[triangleIndex2[base][i]]];
        [gSymbolTrianglePath2[base] closePath];
    }
}

- (void) configure {
    if (!gConfig) gConfig = [YLLGlobalConfig sharedInstance];
	gColumn = [gConfig column];
	gRow = [gConfig row];
    _fontWidth = [gConfig cellWidth];
    _fontHeight = [gConfig cellHeight];
	
    NSRect frame = [self frame];
	frame.size = NSMakeSize(gColumn * [gConfig cellWidth], gRow * [gConfig cellHeight]);
    frame.origin = NSZeroPoint;
    [self setFrame: frame];

    [self createSymbolPath];

    [_backedImage release];
    _backedImage = [[NSImage alloc] initWithSize: frame.size];
    [_backedImage setFlipped: NO];

    [gLeftImage release]; 
    gLeftImage = [[NSImage alloc] initWithSize: NSMakeSize(_fontWidth, _fontHeight)];			

    if (!gSingleAdvance) gSingleAdvance = (CGSize *) malloc(sizeof(CGSize) * gColumn);
    if (!gDoubleAdvance) gDoubleAdvance = (CGSize *) malloc(sizeof(CGSize) * gColumn);

    for (int i = 0; i < gColumn; i++) {
        gSingleAdvance[i] = CGSizeMake(_fontWidth * 1.0, 0.0);
        gDoubleAdvance[i] = CGSizeMake(_fontWidth * 2.0, 0.0);
    }
    [_markedText release];
    _markedText = nil;

    _selectedRange = NSMakeRange(NSNotFound, 0);
    _markedRange = NSMakeRange(NSNotFound, 0);
    
    [_textField setHidden: YES];
}

- (id)initWithFrame:(NSRect)frame {
    if (self = [super initWithFrame:frame]) {
        [self configure];
        _selectionLength = 0;
        _selectionLocation = 0;
		_isInPortalMode = NO;
 		_ipTrackingRects = [[XIIntegerArray alloc] init];
		_clickEntryTrackingRects = [[XIIntegerArray alloc] init];
		_buttonTrackingRects = [[XIIntegerArray alloc] init];
		_trackingRectDataList = [[NSMutableArray alloc] initWithCapacity:20];
		//_effectView = [[KOEffectView alloc] initWithFrame:frame];
    }
    return self;
}

- (void)dealloc {
    [_backedImage release];
    [_portal release];
	
	[_ipTrackingRects release];
	[_clickEntryTrackingRects release];
	[_buttonTrackingRects release];
	[_trackingRectDataList release];
    [super dealloc];
}

#pragma mark -
#pragma mark Actions

- (void) copy: (id) sender {
    if (![self connected]) return;
    if (_selectionLength == 0) return;

    NSString *s = [self selectedPlainString];
    
    /* Color copy */
    int location, length;
    if (_selectionLength >= 0) {
        location = _selectionLocation;
        length = _selectionLength;
    } else {
        location = _selectionLocation + _selectionLength;
        length = 0 - (int)_selectionLength;
    }

    cell *buffer = (cell *) malloc((length + gRow + gColumn + 1) * sizeof(cell));
    int i, j;
    int bufferLength = 0;
    id ds = [self frontMostTerminal];
    int emptyCount = 0;

    for (i = 0; i < length; i++) {
        int index = location + i;
        cell *currentRow = [ds cellsOfRow: index / gColumn];
        
        if ((index % gColumn == 0) && (index != location)) {
            buffer[bufferLength].byte = '\n';
            buffer[bufferLength].attr = buffer[bufferLength - 1].attr;
            bufferLength++;
            emptyCount = 0;
        }
        if (currentRow[index % gColumn].byte != '\0') {
            for (j = 0; j < emptyCount; j++) {
                buffer[bufferLength] = currentRow[index % gColumn];
                buffer[bufferLength].byte = ' ';
                buffer[bufferLength].attr.f.doubleByte = 0;
                buffer[bufferLength].attr.f.url = 0;
                buffer[bufferLength].attr.f.nothing = 0;
                bufferLength++;   
            }
            buffer[bufferLength] = currentRow[index % gColumn];
            /* Clear non-ANSI related properties. */
            buffer[bufferLength].attr.f.doubleByte = 0;
            buffer[bufferLength].attr.f.url = 0;
            buffer[bufferLength].attr.f.nothing = 0;
            bufferLength++;
            emptyCount = 0;
        } else {
            emptyCount++;
        }
    }
    
    NSPasteboard *pb = [NSPasteboard generalPasteboard];
    NSMutableArray *types = [NSMutableArray arrayWithObjects: NSStringPboardType, ANSIColorPBoardType, nil];
    if (!s) s = @"";
    [pb declareTypes: types owner: self];
    [pb setString: s forType: NSStringPboardType];
    [pb setData: [NSData dataWithBytes: buffer length: bufferLength * sizeof(cell)] forType: ANSIColorPBoardType];
    free(buffer);
}

- (void) pasteColor: (id) sender {
    if (![self connected]) return;
	YLTerminal *terminal = [self frontMostTerminal];
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"SafePaste"] && [terminal bbsState].state != BBSComposePost) {
		NSBeginAlertSheet(NSLocalizedString(@"Are you sure you want to paste?", @"Sheet Title"),
						  NSLocalizedString(@"Confirm", @"Default Button"),
						  NSLocalizedString(@"Cancel", @"Cancel Button"),
						  nil,
						  [self window],
						  self,
						  @selector(confirmPasteColor:returnCode:contextInfo:),
						  nil,
						  nil,
						  NSLocalizedString(@"It seems that you are not in edit mode. Pasting may cause unpredictable behaviors. Are you sure you want to paste?", @"Sheet Message"));
	} else {
		[self performPasteColor];
	}
}

- (void) paste: (id) sender {
    if (![self connected]) return;
	YLTerminal *terminal = [self frontMostTerminal];
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"SafePaste"] && [terminal bbsState].state != BBSComposePost) {
		NSBeginAlertSheet(NSLocalizedString(@"Are you sure you want to paste?", @"Sheet Title"),
						  NSLocalizedString(@"Confirm", @"Default Button"),
						  NSLocalizedString(@"Cancel", @"Cancel Button"),
						  nil,
						  [self window],
						  self,
						  @selector(confirmPaste:returnCode:contextInfo:),
						  nil,
						  nil,
						  NSLocalizedString(@"It seems that you are not in edit mode. Pasting may cause unpredictable behaviors. Are you sure you want to paste?", @"Sheet Message"));
	} else {
		[self performPaste];
	}
}

- (void)pasteWrap:(id)sender {
    if (![self connected]) return;
	YLTerminal *terminal = [self frontMostTerminal];
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"SafePaste"] && [terminal bbsState].state != BBSComposePost) {
		NSBeginAlertSheet(NSLocalizedString(@"Are you sure you want to paste?", @"Sheet Title"),
						  NSLocalizedString(@"Confirm", @"Default Button"),
						  NSLocalizedString(@"Cancel", @"Cancel Button"),
						  nil,
						  [self window],
						  self,
						  @selector(confirmPasteWrap:returnCode:contextInfo:),
						  nil,
						  nil,
						  NSLocalizedString(@"It seems that you are not in edit mode. Pasting may cause unpredictable behaviors. Are you sure you want to paste?", @"Sheet Message"));
	} else {
		[self performPasteWrap];
	}
}

- (void) selectAll: (id) sender {
    if (![self connected]) return;
    _selectionLocation = 0;
    _selectionLength = gRow * gColumn;
    [self setNeedsDisplay: YES];
}

- (BOOL) validateMenuItem: (NSMenuItem *) item {
    SEL action = [item action];
    if (action == @selector(copy:) && (![self connected] || _selectionLength == 0)) {
        return NO;
    } else if ((action == @selector(paste:) || 
                action == @selector(pasteWrap:) || 
                action == @selector(pasteColor:)) && ![self connected]) {
        return NO;
    } else if (action == @selector(selectAll:)  && ![self connected]) {
        return NO;
    } 
    return YES;
}

- (void) refreshHiddenRegion {
    if (![self connected]) return;
    int i, j;
    for (i = 0; i < gRow; i++) {
        cell *currRow = [[self frontMostTerminal] cellsOfRow: i];
        for (j = 0; j < gColumn; j++)
            if (isHiddenAttribute(currRow[j].attr)) 
                [[self frontMostTerminal] setDirty: YES atRow: i column: j];
    }
}

#pragma mark -
#pragma mark Conversion

- (int) convertIndexFromPoint: (NSPoint) p {
	// The following 2 lines: for full screen mode
	NSRect frame = [self frame];
	p.y -= 2 * frame.origin.y;
	
    if (p.x >= gColumn * _fontWidth) p.x = gColumn * _fontWidth - 0.001;
    if (p.y >= gRow * _fontHeight) p.y = gRow * _fontHeight - 0.001;
    if (p.x < 0) p.x = 0;
    if (p.y < 0) p.y = 0;
    int cx, cy = 0;
    cx = (int) ((CGFloat) p.x / _fontWidth);
    cy = gRow - (int) ((CGFloat) p.y / _fontHeight) - 1;
    return cy * gColumn + cx;
}


#pragma mark -
#pragma mark Event Handling
- (void)mouseEntered:(NSEvent *)theEvent {
	NSRect rect = [[theEvent trackingArea] rect];
	KOTrackingRectData *rectData = (KOTrackingRectData *)[theEvent userData];
	switch (rectData->type) {
		case IP_ADDR:
			[_effectView drawIPAddrBox: rect];
			break;
		case CLICK_ENTRY:
		case MAIN_MENU_CLICK_ENTRY:
			// FIXME: remove the following line if preference is done
			if([[[self frontMostConnection] site] enableMouse]) {
				NSCursor * cursor = [NSCursor pointingHandCursor];
				[cursor push];
				[_effectView drawClickEntry: rect];
				_clickEntryData = rectData;
			}
			break;
		case EXIT_AREA:
			if([[self frontMostConnection] connected] && [[[self frontMostConnection] site] enableMouse]) {
				_isMouseInExitArea = YES;
			}
			break;
		case PG_UP_AREA:
			if([[self frontMostConnection] connected] && [[[self frontMostConnection] site] enableMouse]) {
				_isMouseInPgUpArea = YES;
			}
			break;
		case PG_DOWN_AREA:
			if([[self frontMostConnection] connected] && [[[self frontMostConnection] site] enableMouse]) {
				_isMouseInPgDownArea = YES;
			}
			break;
		case BUTTON:
			if([[self frontMostConnection] connected] && [[[self frontMostConnection] site] enableMouse]) {
				[_effectView drawButton:rect withMessage:[[rectData getButtonText] retain]];
				NSCursor * cursor = [NSCursor pointingHandCursor];
				[cursor push];
				_buttonData = rectData;
			}
			break;
		default:
			break;
	}
}

- (void)mouseExited:(NSEvent *)theEvent {
	KOTrackingRectData *rectData = (KOTrackingRectData *)[theEvent userData];
	switch (rectData->type) {
		case IP_ADDR:
			[_effectView clearIPAddrBox];
			break;
		case CLICK_ENTRY:
		case MAIN_MENU_CLICK_ENTRY:
			[_effectView clearClickEntry];
			[NSCursor pop];
			_clickEntryData = nil;
			break;
		case EXIT_AREA:
			_isMouseInExitArea = NO;
			break;
		case PG_UP_AREA:
			_isMouseInPgUpArea = NO;
			break;
		case PG_DOWN_AREA:
			_isMouseInPgDownArea = NO;
			break;
		case BUTTON:
			[_effectView clearButton];
			[NSCursor pop];
			_buttonData = nil;
			break;
		default:
			break;
	}
}

- (void)mouseDown:(NSEvent *)theEvent {
	[[self frontMostConnection] resetMessageCount];
    [[self window] makeFirstResponder:self];

    NSPoint p = [theEvent locationInWindow];
    p = [self convertPoint:p toView:nil];
    // portal
    if (_isInPortalMode) {
        [_portal clickAtPoint:p count:[theEvent clickCount]];
        return;
    }

    if (![self connected]) return;

    _selectionLocation = [self convertIndexFromPoint: p];
    _selectionLength = 0;
    
    if (([theEvent modifierFlags] & NSCommandKeyMask) == 0x00 &&
        [theEvent clickCount] == 3) {
        _selectionLocation = _selectionLocation - (_selectionLocation % gColumn);
        _selectionLength = gColumn;
    } else if (([theEvent modifierFlags] & NSCommandKeyMask) == 0x00 &&
               [theEvent clickCount] == 2) {
        int r = _selectionLocation / gColumn;
        int c = _selectionLocation % gColumn;
        cell *currRow = [[self frontMostTerminal] cellsOfRow: r];
        [[self frontMostTerminal] updateDoubleByteStateForRow: r];
        if (currRow[c].attr.f.doubleByte == 1) { // Double Byte
            _selectionLength = 2;
        } else if (currRow[c].attr.f.doubleByte == 2) {
            _selectionLocation--;
            _selectionLength = 2;
        } else if (isEnglishNumberAlphabet(currRow[c].byte)) { // Not Double Byte
            for (; c >= 0; c--) {
                if (isEnglishNumberAlphabet(currRow[c].byte) && currRow[c].attr.f.doubleByte == 0) 
                    _selectionLocation = r * gColumn + c;
                else 
                    break;
            }
            for (c = c + 1; c < gColumn; c++) {
                if (isEnglishNumberAlphabet(currRow[c].byte) && currRow[c].attr.f.doubleByte == 0) 
                    _selectionLength++;
                else 
                    break;
            }
        } else {
            _selectionLength = 1;
        }
    }
    
    [self setNeedsDisplay: YES];
	//    [super mouseDown: e];
}

- (void) mouseDragged: (NSEvent *) e {
    if (![self connected]) return;
    NSPoint p = [e locationInWindow];
    p = [self convertPoint: p toView: nil];
    int index = [self convertIndexFromPoint: p];
    int oldValue = _selectionLength;
    _selectionLength = index - _selectionLocation + 1;
    if (_selectionLength <= 0) _selectionLength--;
    if (oldValue != _selectionLength)
        [self setNeedsDisplay: YES];
    // TODO: Calculate the precise region to redraw
}


- (void)mouseUp:(NSEvent *)theEvent {
    if (![self connected]) return;
    NSPoint p = [theEvent locationInWindow];
    p = [self convertPoint:p toView:nil];
    // open url
	
	// For Test
	//KOMenuItem *item = [KOMenuItem itemWithName: @"TEST"];
	//KOMenuItem *item2 = [KOMenuItem itemWithName: @"TEST2"];
	//[_effectView showMenuAtPoint: p withItems: [NSArray arrayWithObjects: [item retain], [item2 retain]]];

    if (abs(_selectionLength) <= 1) {
        int index = [self convertIndexFromPoint:p];
        NSString *url = [[self frontMostTerminal] urlStringAtRow:(index / gColumn) column:(index % gColumn)];
        if (url != nil) {
			if (([theEvent modifierFlags] & NSShiftKeyMask) == NSShiftKeyMask) {
				// click while holding shift key or navigate web pages
				// open the URL with browser
				[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:url]];
			} else {
				// open with previewer
				[XIPreviewController dowloadWithURL:[NSURL URLWithString:url]];
			}
			return;	// click on url should not invoke hot spot
		}
		
		// click to move cursor
		if ([[self frontMostTerminal] bbsState].state == BBSComposePost) {
			unsigned char cmd[gRow * gColumn * 3];
			unsigned int cmdLength = 0;
			id ds = [self frontMostTerminal];
			// FIXME: what actually matters is whether the user enables auto-break-line
			// however, since it is enabled by default in smth (switchible by ctrl-p) and disabled in ptt,
			// we temporarily use bbsType here...
			if ([ds bbsType] == TYMaple) { // auto-break-line IS NOT enabled in bbs
				int moveToRow = _selectionLocation / gColumn;
				int moveToCol = _selectionLocation % gColumn;
				BOOL home = NO;
				if (moveToRow > [ds cursorRow]) {
					cmd[cmdLength++] = 0x01;
					home = YES;
					for (int i = [ds cursorRow]; i < moveToRow; i++) {
						cmd[cmdLength++] = 0x1B;
						cmd[cmdLength++] = 0x4F;
						cmd[cmdLength++] = 0x42;
					} 
				} else if (moveToRow < [ds cursorRow]) {
					cmd[cmdLength++] = 0x01;
					home = YES;
					for (int i = [ds cursorRow]; i > moveToRow; i--) {
						cmd[cmdLength++] = 0x1B;
						cmd[cmdLength++] = 0x4F;
						cmd[cmdLength++] = 0x41;
					} 			
				} 
				
				cell *currRow = [[self frontMostTerminal] cellsOfRow: moveToRow];
				if (home) {
					for (int i = 0; i < moveToCol; i++) {
						if (currRow[i].attr.f.doubleByte != 2 || [[[self frontMostConnection] site] detectDoubleByte]) {
							cmd[cmdLength++] = 0x1B;
							cmd[cmdLength++] = 0x4F;
							cmd[cmdLength++] = 0x43;                    
						}
					}
				} else if (moveToCol > [ds cursorColumn]) {
					for (int i = [ds cursorColumn]; i < moveToCol; i++) {
						if (currRow[i].attr.f.doubleByte != 2 || [[[self frontMostConnection] site] detectDoubleByte]) {
							cmd[cmdLength++] = 0x1B;
							cmd[cmdLength++] = 0x4F;
							cmd[cmdLength++] = 0x43;
						}
					}
				} else if (moveToCol < [ds cursorColumn]) {
					for (int i = [ds cursorColumn]; i > moveToCol; i--) {
						if (currRow[i].attr.f.doubleByte != 2 || [[[self frontMostConnection] site] detectDoubleByte]) {
							cmd[cmdLength++] = 0x1B;
							cmd[cmdLength++] = 0x4F;
							cmd[cmdLength++] = 0x44;
						}
					}
				}
			} else { // auto-break-line IS enabled in bbs
				int thisRow = [ds cursorRow];
				int cursorLocation = thisRow * gColumn + [ds cursorColumn];
				int prevRow = -1;
				int lastEffectiveChar;
				if (cursorLocation < _selectionLocation) {
					for (int i = cursorLocation; i < _selectionLocation; ++i) {
						thisRow = i / gColumn;
						if (thisRow != prevRow) {
							cell *currRow = [ds cellsOfRow:thisRow];
							for (lastEffectiveChar = gColumn - 1;
								 lastEffectiveChar != 0
								 && (currRow[lastEffectiveChar - 1].byte == 0 || currRow[lastEffectiveChar - 1].byte == '~');
								 --lastEffectiveChar);
							prevRow = thisRow;
						}
						if (i % gColumn <= lastEffectiveChar
							&& ([ds attrAtRow:i / gColumn column:i % gColumn].f.doubleByte != 2
								|| [[[self frontMostConnection] site] detectDoubleByte])) {
							cmd[cmdLength++] = 0x1B;
							cmd[cmdLength++] = 0x4F;
							cmd[cmdLength++] = 0x43;                    
						}
					}
				} else {
					for (int i = cursorLocation; i > _selectionLocation; --i) {
						thisRow = i / gColumn;
						if (thisRow != prevRow) {
							cell *currRow = [ds cellsOfRow:thisRow];
							for (lastEffectiveChar = gColumn - 1;
								 lastEffectiveChar != 0
								 && (currRow[lastEffectiveChar - 1].byte == 0 || currRow[lastEffectiveChar - 1].byte == '~');
								 --lastEffectiveChar);
							prevRow = thisRow;
						}
						if (i % gColumn <= lastEffectiveChar
							&& ([ds attrAtRow:i / gColumn column:i % gColumn].f.doubleByte != 2
								|| [[[self frontMostConnection] site] detectDoubleByte])) {
							cmd[cmdLength++] = 0x1B;
							cmd[cmdLength++] = 0x4F;
							cmd[cmdLength++] = 0x44;                    
						}					
					}
				}				
			}
			if (cmdLength > 0) 
				[[self frontMostConnection] sendBytes: cmd length: cmdLength];
		}
		
		
		if (![[[self frontMostConnection] site] enableMouse])
			return;
		
		if (_clickEntryData != nil) {
			if (_clickEntryData->commandSequence != nil) {
				//NSLog(_clickEntryData->commandSequence);
				[[self frontMostConnection] sendText: _clickEntryData->commandSequence];
				return;
			}
			
			unsigned char cmd[gRow * gColumn + 1];
			unsigned int cmdLength = 0;
			id ds = [self frontMostTerminal];
			int moveToRow = _clickEntryData->row;
			int cursorRow = [ds cursorRow];
			
			//NSLog(@"moveToRow: %d, cursorRow: %d, [ds cursorRow]: %d", moveToRow, cursorRow, [ds cursorRow]);
			//NSLog(@"title = %@", _clickEntryData->postTitle);
			
			if (moveToRow > cursorRow) {
				//cmd[cmdLength++] = 0x01;
				for (int i = cursorRow; i < moveToRow; i++) {
					cmd[cmdLength++] = 0x1B;
					cmd[cmdLength++] = 0x4F;
					cmd[cmdLength++] = 0x42;
				} 
			} else if (moveToRow < cursorRow) {
				//cmd[cmdLength++] = 0x01;
				for (int i = cursorRow; i > moveToRow; i--) {
					cmd[cmdLength++] = 0x1B;
					cmd[cmdLength++] = 0x4F;
					cmd[cmdLength++] = 0x41;
				} 
			}
			
			cmd[cmdLength++] = 0x0D;
			
			[[self frontMostConnection] sendBytes: cmd length: cmdLength];
			return;
		}
		if (_buttonData) {
			[[self frontMostConnection] sendText: _buttonData->commandSequence];
			return;
		}
		
		if (_isMouseInExitArea
			&& [[self frontMostTerminal] bbsState].state != BBSWaitingEnter
			&& [[self frontMostTerminal] bbsState].state != BBSComposePost) {
			[[self frontMostConnection] sendText: termKeyLeft];
			return;
		}
		
		if (_isMouseInPgUpArea ) {
			[[self frontMostConnection] sendText: termKeyPageUp];
			return;
		}
		
		if (_isMouseInPgDownArea ) {
			[[self frontMostConnection] sendText: termKeyPageDown];
			return;
		}
		
		if ([[self frontMostTerminal] bbsState].state == BBSWaitingEnter) {
			[[self frontMostConnection] sendText: termKeyEnter];
		}
    }
}

- (void)scrollWheel:(NSEvent *)theEvent {
    // portal
    if (_isInPortalMode) {
        if ([theEvent deltaY] > 0)
            [_portal moveSelection:-1];
        else if ([theEvent deltaY] < 0)
            [_portal moveSelection:+1];
    }
	// Connected terminal
	if([[[self frontMostTerminal] connection] connected]) {
		// For Y-Axis
		if([theEvent deltaY] < 0)
			[[self frontMostConnection] sendText:termKeyDown];
		else if([theEvent deltaY] > 0) {
			[[self frontMostConnection] sendText:termKeyUp];
		}
	}
}

- (void)keyDown:(NSEvent *)theEvent {    
    [[self frontMostConnection] resetMessageCount];
	
    unichar c = [[theEvent characters] characterAtIndex:0];
    // portal
    if (_isInPortalMode) {
        switch (c) {
        case NSLeftArrowFunctionKey:
            [_portal moveSelection:-1];
            break;
        case NSRightArrowFunctionKey:
            [_portal moveSelection:+1];
            break;
        case ' ':
        case '\r':
            [_portal select];
            break;
        }
        return;
    }
	
	// Url menu
	if(_isInUrlMode) {
		NSLog(@"!");
		switch (c) {
			case NSUpArrowFunctionKey:
				NSLog(@"Select prev url");
				break;
			case NSDownArrowFunctionKey:
				NSLog(@"Select next url");
				break;
			default:
				NSLog(@"%d, %d, %d", c, NSUpArrowFunctionKey, NSDownArrowFunctionKey);
		}
		return;
	}

    [self clearSelection];
	unsigned char arrow[6] = {0x1B, 0x4F, 0x00, 0x1B, 0x4F, 0x00};
	unsigned char buf[10];

    YLTerminal *ds = [self frontMostTerminal];

    if ([theEvent modifierFlags] & NSControlKeyMask) {
        buf[0] = c;
        [[self frontMostConnection] sendBytes:buf length:1];
        return;
    }
	
	if (c == NSUpArrowFunctionKey) arrow[2] = arrow[5] = 'A';
	if (c == NSDownArrowFunctionKey) arrow[2] = arrow[5] = 'B';
	if (c == NSRightArrowFunctionKey) arrow[2] = arrow[5] = 'C';
	if (c == NSLeftArrowFunctionKey) arrow[2] = arrow[5] = 'D';
	
	if (![self hasMarkedText] && 
		(c == NSUpArrowFunctionKey ||
		 c == NSDownArrowFunctionKey ||
		 c == NSRightArrowFunctionKey || 
		 c == NSLeftArrowFunctionKey)) {
        [ds updateDoubleByteStateForRow: [ds cursorRow]];
        if ((c == NSRightArrowFunctionKey && [ds attrAtRow: [ds cursorRow] column: [ds cursorColumn]].f.doubleByte == 1) || 
            (c == NSLeftArrowFunctionKey && [ds cursorColumn] > 0 && [ds attrAtRow: [ds cursorRow] column: [ds cursorColumn] - 1].f.doubleByte == 2))
            if ([[[self frontMostConnection] site] detectDoubleByte]) {
                [[self frontMostConnection] sendBytes: arrow length: 6];
                return;
            }
        
		[[self frontMostConnection] sendBytes: arrow length: 3];
		return;
	}
	
	if (![self hasMarkedText] && (c == NSDeleteCharacter)) {
		//buf[0] = buf[1] = NSBackspaceCharacter;
		// Modified by K.O.ed: using 0x7F instead of 0x08
		buf[0] = buf[1] = NSDeleteCharacter;
        if ([[[self frontMostConnection] site] detectDoubleByte] &&
            [ds cursorColumn] > 0 && [ds attrAtRow: [ds cursorRow] column: [ds cursorColumn] - 1].f.doubleByte == 2)
            [[self frontMostConnection] sendBytes: buf length: 2];
        else
            [[self frontMostConnection] sendBytes: buf length: 1];
        return;
	}

	[self interpretKeyEvents:[NSArray arrayWithObject:theEvent]];
}

- (void) flagsChanged: (NSEvent *) event {
	/*
	unsigned int currentFlags = [event modifierFlags];
	// for Url menu
	if((currentFlags & NSShiftKeyMask) && (currentFlags & NSControlKeyMask) && !_isInUrlMode) {
		_isInUrlMode = YES;
		//NSLog(@"Enter url state");
		[super flagsChanged:event];
		return;
	} else if (_isInUrlMode) {
		_isInUrlMode = NO;
		//NSLog(@"Exit Url state");
		[super flagsChanged:event];
		return;
	}
	// for old things...
	NSCursor *viewCursor = nil;
	if (currentFlags & NSCommandKeyMask) {
		viewCursor = gMoveCursor;
	} else {
		viewCursor = [NSCursor arrowCursor];
	}
	[viewCursor set];
	 */
	[super flagsChanged: event];
}

- (void) clearSelection {
    if (_selectionLength != 0) {
        _selectionLength = 0;
        [self setNeedsDisplay: YES];
    }
}

#pragma mark -
#pragma mark Drawing

- (void) displayCellAtRow: (int) r column: (int) c {
    [self setNeedsDisplayInRect: NSMakeRect(c * _fontWidth, (gRow - 1 - r) * _fontHeight, _fontWidth, _fontHeight)];
}

- (void) tick: (NSArray *) a {
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
	[self updateBackedImage];
    YLTerminal *ds = [self frontMostTerminal];

	if (ds && (_x != ds->_cursorX || _y != ds->_cursorY)) {
		[self setNeedsDisplayInRect: NSMakeRect(_x * _fontWidth, (gRow - 1 - _y) * _fontHeight, _fontWidth, _fontHeight)];
		[self setNeedsDisplayInRect: NSMakeRect(ds->_cursorX * _fontWidth, (gRow - 1 - ds->_cursorY) * _fontHeight, _fontWidth, _fontHeight)];
		_x = ds->_cursorX;
		_y = ds->_cursorY;
	}
    [pool release];
}

- (NSRect) cellRectForRect: (NSRect) r {
	int originx = r.origin.x / _fontWidth;
	int originy = r.origin.y / _fontHeight;
	int width = ((r.size.width + r.origin.x) / _fontWidth) - originx + 1;
	int height = ((r.size.height + r.origin.y) / _fontHeight) - originy + 1;
	return NSMakeRect(originx, originy, width, height);
}

- (void)drawRect:(NSRect)rect {
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
    YLTerminal *ds = [self frontMostTerminal];
	if ([self connected]) {
		// NSLog(@"connected");
		// Modified by gtCarrera
		// Draw the background color first!!!
		[[gConfig colorBG] set];
        NSRect retangle = [self bounds];
		NSRectFill(retangle);
        /* Draw the backed image */
		
		NSRect imgRect = rect;
		imgRect.origin.y = (_fontHeight * gRow) - rect.origin.y - rect.size.height;
		[_backedImage compositeToPoint: rect.origin
							  fromRect: rect
							 operation: NSCompositeCopy];
        [self drawBlink];
        
        /* Draw the url underline */
        int c, r;
        [[NSColor orangeColor] set];
        [NSBezierPath setDefaultLineWidth: 1.0];
        for (r = 0; r < gRow; r++) {
            cell *currRow = [ds cellsOfRow: r];
            for (c = 0; c < gColumn; c++) {
                int start;
                for (start = c; c < gColumn && currRow[c].attr.f.url; c++) ;
                if (c != start) {
                    [NSBezierPath strokeLineFromPoint: NSMakePoint(start * _fontWidth, (gRow - r - 1) * _fontHeight + 0.5) 
                                              toPoint: NSMakePoint(c * _fontWidth, (gRow - r - 1) * _fontHeight + 0.5)];
                }
            }
        }
        
		/* Draw the cursor */
		[[NSColor whiteColor] set];
		[NSBezierPath setDefaultLineWidth: 2.0];
		[NSBezierPath strokeLineFromPoint: NSMakePoint(ds->_cursorX * _fontWidth, (gRow - 1 - ds->_cursorY) * _fontHeight + 1) 
								  toPoint: NSMakePoint((ds->_cursorX + 1) * _fontWidth, (gRow - 1 - ds->_cursorY) * _fontHeight + 1) ];
        [NSBezierPath setDefaultLineWidth: 1.0];
        _x = ds->_cursorX, _y = ds->_cursorY;

        /* Draw the selection */
        if (_selectionLength != 0) 
            [self drawSelection];
	} else {
		// NSLog(@"Not connected!");
		[[gConfig colorBG] set];
        NSRect r = [self bounds];
        NSRectFill(r);
	}
	
	[_effectView resize];
    [pool release];
}

- (void) drawBlink {
    if (![gConfig blinkTicker]) return;

    NSAutoreleasePool *pool = [NSAutoreleasePool new];
	
    int c, r;
    id ds = [self frontMostTerminal];
    if (!ds) return;
    for (r = 0; r < gRow; r++) {
        cell *currRow = [ds cellsOfRow: r];
        for (c = 0; c < gColumn; c++) {
            if (isBlinkCell(currRow[c])) {
                int bgColorIndex = currRow[c].attr.f.reverse ? currRow[c].attr.f.fgColor : currRow[c].attr.f.bgColor;
                BOOL bold = currRow[c].attr.f.reverse ? currRow[c].attr.f.bold : NO;
                [[gConfig colorAtIndex: bgColorIndex hilite: bold] set];
                NSRectFill(NSMakeRect(c * _fontWidth, (gRow - r - 1) * _fontHeight, _fontWidth, _fontHeight));
            }
        }
    }
    
    [pool release];
}

- (void) drawSelection {
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
    int location, length;
    if (_selectionLength >= 0) {
        location = _selectionLocation;
        length = _selectionLength;
    } else {
        location = _selectionLocation + _selectionLength;
        length = 0 - (int)_selectionLength;
    }
    int x = location % gColumn;
    int y = location / gColumn;
    [[NSColor colorWithCalibratedRed: 0.6 green: 0.9 blue: 0.6 alpha: 0.4] set];

    while (length > 0) {
        if (x + length <= gColumn) { // one-line
            [NSBezierPath fillRect: NSMakeRect(x * _fontWidth, (gRow - y - 1) * _fontHeight, _fontWidth * length, _fontHeight)];
            length = 0;
        } else {
            [NSBezierPath fillRect: NSMakeRect(x * _fontWidth, (gRow - y - 1) * _fontHeight, _fontWidth * (gColumn - x), _fontHeight)];
            length -= (gColumn - x);
        }
        x = 0;
        y++;
    }
    [pool release];
}

/* 
	Extend Bottom:
 
		AAAAAAAAAAA			BBBBBBBBBBB
		BBBBBBBBBBB			CCCCCCCCCCC
		CCCCCCCCCCC   ->	DDDDDDDDDDD
		DDDDDDDDDDD			...........
 
 */
- (void) extendBottomFrom: (int) start to: (int) end {
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
	[_backedImage lockFocus];
	[_backedImage compositeToPoint: NSMakePoint(0, (gRow - end) * _fontHeight) 
						  fromRect: NSMakeRect(0, (gRow - end - 1) * _fontHeight, gColumn * _fontWidth, (end - start) * _fontHeight) 
						 operation: NSCompositeCopy];

	[gConfig->_colorTable[0][gConfig->_bgColorIndex] set];
	NSRectFill(NSMakeRect(0, (gRow - end - 1) * _fontHeight, gColumn * _fontWidth, _fontHeight));
	[_backedImage unlockFocus];
    [pool release];
}


/* 
	Extend Top:
		AAAAAAAAAAA			...........
		BBBBBBBBBBB			AAAAAAAAAAA
		CCCCCCCCCCC   ->	BBBBBBBBBBB
		DDDDDDDDDDD			CCCCCCCCCCC
 */
- (void) extendTopFrom: (int) start to: (int) end {
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
    [_backedImage lockFocus];
	[_backedImage compositeToPoint: NSMakePoint(0, (gRow - end - 1) * _fontHeight) 
						  fromRect: NSMakeRect(0, (gRow - end) * _fontHeight, gColumn * _fontWidth, (end - start) * _fontHeight) 
						 operation: NSCompositeCopy];
	
	[gConfig->_colorTable[0][gConfig->_bgColorIndex] set];
	NSRectFill(NSMakeRect(0, (gRow - start - 1) * _fontHeight, gColumn * _fontWidth, _fontHeight));
	[_backedImage unlockFocus];
    [pool release];
}

- (void) updateBackedImage {
	//NSLog(@"Image");
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
	int x, y;
    YLTerminal *ds = [self frontMostTerminal];
	[_backedImage lockFocus];
	[self refreshAllHotSpots];
	CGContextRef myCGContext = (CGContextRef)[[NSGraphicsContext currentContext] graphicsPort];
	if (ds) {
        /* Draw Background */
        for (y = 0; y < gRow; y++) {
            for (x = 0; x < gColumn; x++) {
                if ([ds isDirtyAtRow: y column: x]) {
                    int startx = x;
                    for (; x < gColumn && [ds isDirtyAtRow:y column:x]; x++) ;
                    [self updateBackgroundForRow: y from: startx to: x];
                }
            }
        }
        CGContextSaveGState(myCGContext);
        CGContextSetShouldSmoothFonts(myCGContext, 
                                      gConfig->_shouldSmoothFonts == YES ? true : false);
        
        /* Draw String row by row */
        for (y = 0; y < gRow; y++) {
            [self drawStringForRow: y context: myCGContext];
        }
        CGContextRestoreGState(myCGContext);
        
        for (y = 0; y < gRow; y++) {
            for (x = 0; x < gColumn; x++) {
                [ds setDirty: NO atRow: y column: x];
            }
        }
    } else {
        [[NSColor clearColor] set];
        CGContextFillRect(myCGContext, CGRectMake(0, 0, gColumn * _fontWidth, gRow * _fontHeight));
    }

	[_backedImage unlockFocus];
    [pool release];
	return;
}

- (void) drawStringForRow: (int) r context: (CGContextRef) myCGContext {
	int i, c, x;
	int start, end;
	unichar textBuf[gColumn];
	BOOL isDoubleByte[gColumn];
	BOOL isDoubleColor[gColumn];
	int bufIndex[gColumn];
	int runLength[gColumn];
	CGPoint position[gColumn];
	int bufLength = 0;
    
    CGFloat ePaddingLeft = [gConfig englishFontPaddingLeft], ePaddingBottom = [gConfig englishFontPaddingBottom];
    CGFloat cPaddingLeft = [gConfig chineseFontPaddingLeft], cPaddingBottom = [gConfig chineseFontPaddingBottom];
    
    YLTerminal *ds = [self frontMostTerminal];
    [ds updateDoubleByteStateForRow: r];
	
    cell *currRow = [ds cellsOfRow: r];

	for (i = 0; i < gColumn; i++) 
		isDoubleColor[i] = isDoubleByte[i] = textBuf[i] = runLength[i] = 0;

    // find the first dirty position in this row
	for (x = 0; x < gColumn && ![ds isDirtyAtRow: r column: x]; x++) ;
	// all clean? great!
    if (x == gColumn) return; 
    
	start = x;

    // update the information array
	for (x = start; x < gColumn; x++) {
		if (![ds isDirtyAtRow: r column: x]) continue;
		end = x;
		int db = (currRow + x)->attr.f.doubleByte;

		if (db == 0) {
            isDoubleByte[bufLength] = NO;
            textBuf[bufLength] = 0x0000 + (currRow[x].byte ?: ' ');
            bufIndex[bufLength] = x;
            position[bufLength] = CGPointMake(x * _fontWidth + ePaddingLeft, (gRow - 1 - r) * _fontHeight + CTFontGetDescent(gConfig->_eCTFont) + ePaddingBottom);
            isDoubleColor[bufLength] = NO;
            bufLength++;
		} else if (db == 1) {
			continue;
		} else if (db == 2) {
			unsigned short code = (((currRow + x - 1)->byte) << 8) + ((currRow + x)->byte) - 0x8000;
			unichar ch = [[[self frontMostConnection] site] encoding] == YLBig5Encoding ? B2U[code] : G2U[code];
			//NSLog(@"r = %d, x = %d, ch = %d", r, x, ch);
			if (isSpecialSymbol(ch)) {
				[self drawSpecialSymbol: ch forRow: r column: (x - 1) leftAttribute: (currRow + x - 1)->attr rightAttribute: (currRow + x)->attr];
			} else {
                isDoubleColor[bufLength] = (fgColorIndexOfAttribute(currRow[x - 1].attr) != fgColorIndexOfAttribute(currRow[x].attr) || 
                                            fgBoldOfAttribute(currRow[x - 1].attr) != fgBoldOfAttribute(currRow[x].attr));
				isDoubleByte[bufLength] = YES;
				textBuf[bufLength] = ch;
				bufIndex[bufLength] = x;
				position[bufLength] = CGPointMake((x - 1) * _fontWidth + cPaddingLeft, (gRow - 1 - r) * _fontHeight + CTFontGetDescent(gConfig->_cCTFont) + cPaddingBottom);
				bufLength++;
			}
            // FIXME: why?
			if (x == start)
				[self setNeedsDisplayInRect: NSMakeRect((x - 1) * _fontWidth, (gRow - 1 - r) * _fontHeight, _fontWidth, _fontHeight)];
		}
	}

	CFStringRef str = CFStringCreateWithCharacters(kCFAllocatorDefault, textBuf, bufLength);
	CFAttributedStringRef attributedString = CFAttributedStringCreate(kCFAllocatorDefault, str, NULL);
	CFMutableAttributedStringRef mutableAttributedString = CFAttributedStringCreateMutableCopy(kCFAllocatorDefault, 0, attributedString);
	CFRelease(str);
	CFRelease(attributedString);
    
	/* Run-length of the style */
	c = 0;
	while (c < bufLength) {
		int location = c;
		int length = 0;
		BOOL db = isDoubleByte[c];

		attribute currAttr, lastAttr = (currRow + bufIndex[c])->attr;
		for (; c < bufLength; c++) {
			currAttr = (currRow + bufIndex[c])->attr;
			if (currAttr.v != lastAttr.v || isDoubleByte[c] != db) break;
		}
		length = c - location;
		
		CFDictionaryRef attr;
		if (db) 
			attr = gConfig->_cCTAttribute[fgBoldOfAttribute(lastAttr)][fgColorIndexOfAttribute(lastAttr)];
		else
			attr = gConfig->_eCTAttribute[fgBoldOfAttribute(lastAttr)][fgColorIndexOfAttribute(lastAttr)];
		CFAttributedStringSetAttributes(mutableAttributedString, CFRangeMake(location, length), attr, YES);
	}
    
	CTLineRef line = CTLineCreateWithAttributedString(mutableAttributedString);
	CFRelease(mutableAttributedString);
	
	CFIndex glyphCount = CTLineGetGlyphCount(line);
	if (glyphCount == 0) {
		CFRelease(line);
		return;
	}
	
	CFArrayRef runArray = CTLineGetGlyphRuns(line);
	CFIndex runCount = CFArrayGetCount(runArray);
	CFIndex glyphOffset = 0;
	
	CFIndex runIndex = 0;
        
	for (; runIndex < runCount; runIndex++) {
		CTRunRef run = (CTRunRef) CFArrayGetValueAtIndex(runArray,  runIndex);
		CFIndex runGlyphCount = CTRunGetGlyphCount(run);
		CFIndex runGlyphIndex = 0;

		CFDictionaryRef attrDict = CTRunGetAttributes(run);
		CTFontRef runFont = (CTFontRef)CFDictionaryGetValue(attrDict,  kCTFontAttributeName);
		CGFontRef cgFont = CTFontCopyGraphicsFont(runFont, NULL);
		NSColor *runColor = (NSColor *) CFDictionaryGetValue(attrDict, kCTForegroundColorAttributeName);
		        
		CGContextSetFont(myCGContext, cgFont);
		CGContextSetFontSize(myCGContext, CTFontGetSize(runFont));
		CGContextSetRGBFillColor(myCGContext, 
								 [runColor redComponent], 
								 [runColor greenComponent], 
								 [runColor blueComponent], 
								 1.0);
        CGContextSetRGBStrokeColor(myCGContext, 1.0, 1.0, 1.0, 1.0);
        CGContextSetLineWidth(myCGContext, 1.0);
        
        int location = runGlyphIndex = 0;
        int lastIndex = bufIndex[glyphOffset];
        BOOL hidden = isHiddenAttribute(currRow[lastIndex].attr);
        BOOL lastDoubleByte = isDoubleByte[glyphOffset];
        
        for (runGlyphIndex = 0; runGlyphIndex <= runGlyphCount; runGlyphIndex++) {
            int index = bufIndex[glyphOffset + runGlyphIndex];
            if (runGlyphIndex == runGlyphCount || 
                (gConfig->_showHiddenText && isHiddenAttribute(currRow[index].attr) != hidden) ||
                (isDoubleByte[runGlyphIndex + glyphOffset] && index != lastIndex + 2) ||
                (!isDoubleByte[runGlyphIndex + glyphOffset] && index != lastIndex + 1) ||
                (isDoubleByte[runGlyphIndex + glyphOffset] != lastDoubleByte)) {
                lastDoubleByte = isDoubleByte[runGlyphIndex + glyphOffset];
                int len = runGlyphIndex - location;
                
                CGContextSetTextDrawingMode(myCGContext, ([gConfig showHiddenText] && hidden) ? kCGTextStroke : kCGTextFill);
                CGGlyph glyph[gColumn];
                CFRange glyphRange = CFRangeMake(location, len);
                CTRunGetGlyphs(run, glyphRange, glyph);
                
                CGAffineTransform textMatrix = CTRunGetTextMatrix(run);
                textMatrix.tx = position[glyphOffset + location].x;
                textMatrix.ty = position[glyphOffset + location].y;
                CGContextSetTextMatrix(myCGContext, textMatrix);
                
                CGContextShowGlyphsWithAdvances(myCGContext, glyph, isDoubleByte[glyphOffset + location] ? gDoubleAdvance : gSingleAdvance, len);
                
                location = runGlyphIndex;
                if (runGlyphIndex != runGlyphCount)
                    hidden = isHiddenAttribute(currRow[index].attr);
            }
            lastIndex = index;
        }
        
        
		/* Double Color */
		for (runGlyphIndex = 0; runGlyphIndex < runGlyphCount; runGlyphIndex++) {
            if (isDoubleColor[glyphOffset + runGlyphIndex]) {
                CFRange glyphRange = CFRangeMake(runGlyphIndex, 1);
                CGGlyph glyph;
                CTRunGetGlyphs(run, glyphRange, &glyph);
                
                int index = bufIndex[glyphOffset + runGlyphIndex] - 1;
                unsigned int bgColor = bgColorIndexOfAttribute(currRow[index].attr);
                unsigned int fgColor = fgColorIndexOfAttribute(currRow[index].attr);
                
                [gLeftImage lockFocus];
                [[gConfig colorAtIndex: bgColor hilite: bgBoldOfAttribute(currRow[index].attr)] set];
                NSRect rect;
                rect.size = [gLeftImage size];
                rect.origin = NSZeroPoint;
                NSRectFill(rect);
                
                CGContextRef tempContext = (CGContextRef)[[NSGraphicsContext currentContext] graphicsPort];
                
                CGContextSetShouldSmoothFonts(tempContext, gConfig->_shouldSmoothFonts == YES ? true : false);
                
                NSColor *tempColor = [gConfig colorAtIndex: fgColor hilite: fgBoldOfAttribute(currRow[index].attr)];
                CGContextSetFont(tempContext, cgFont);
                CGContextSetFontSize(tempContext, CTFontGetSize(runFont));
                CGContextSetRGBFillColor(tempContext, 
                                         [tempColor redComponent], 
                                         [tempColor greenComponent], 
                                         [tempColor blueComponent], 
                                         1.0);
                
                CGContextShowGlyphsAtPoint(tempContext, cPaddingLeft, CTFontGetDescent(gConfig->_cCTFont) + cPaddingBottom, &glyph, 1);
                [gLeftImage unlockFocus];
                [gLeftImage drawAtPoint: NSMakePoint(index * _fontWidth, (gRow - 1 - r) * _fontHeight) fromRect: rect operation: NSCompositeCopy fraction: 1.0];
            }
		}
		glyphOffset += runGlyphCount;
		CFRelease(cgFont);
	}
	
	CFRelease(line);
        
    /* underline */
    for (x = start; x <= end; x++) {
        if (currRow[x].attr.f.underline) {
            unsigned int beginColor = currRow[x].attr.f.reverse ? currRow[x].attr.f.bgColor : currRow[x].attr.f.fgColor;
            BOOL beginBold = !currRow[x].attr.f.reverse && currRow[x].attr.f.bold;
            int begin = x;
            for (; x <= end; x++) {
                unsigned int currentColor = currRow[x].attr.f.reverse ? currRow[x].attr.f.bgColor : currRow[x].attr.f.fgColor;
                BOOL currentBold = !currRow[x].attr.f.reverse && currRow[x].attr.f.bold;
                if (!currRow[x].attr.f.underline || currentColor != beginColor || currentBold != beginBold) 
                    break;
            }
            [[gConfig colorAtIndex: beginColor hilite: beginBold] set];
            [NSBezierPath strokeLineFromPoint: NSMakePoint(begin * _fontWidth, (gRow - 1 - r) * _fontHeight + 0.5) 
                                      toPoint: NSMakePoint(x * _fontWidth, (gRow - 1 - r) * _fontHeight + 0.5)];
            x--;
        }
    }
}

- (void) updateBackgroundForRow: (int) r from: (int) start to: (int) end {
	int c;
	cell *currRow = [[self frontMostTerminal] cellsOfRow: r];
	NSRect rowRect = NSMakeRect(start * _fontWidth, (gRow - 1 - r) * _fontHeight, (end - start) * _fontWidth, _fontHeight);
	
	attribute currAttr, lastAttr = (currRow + start)->attr;
	int length = 0;
	unsigned int currentBackgroundColor;
    BOOL currentBold;
	unsigned int lastBackgroundColor = bgColorIndexOfAttribute(lastAttr);
	BOOL lastBold = bgBoldOfAttribute(lastAttr);
	/* 
        Optimization Idea:
		for example: 
		
		  BBBBBBBBBBBWWWWWWWWWWBBBBBBBBBBB
		
		currently, we draw each color segment one by one, like this:
		
		1. BBBBBBBBBBB
		2. BBBBBBBBBBBWWWWWWWWWW
		3. BBBBBBBBBBBWWWWWWWWWWBBBBBBBBBBB
		
		but we can use only two fillRect: 
	 
		1. BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB
		2. BBBBBBBBBBBWWWWWWWWWWBBBBBBBBBBB
	 
		If further optimization of background drawing is needed, consider the 2D reduction.
     
        NOTE: 2007/12/07
        
        We don't have to reduce the number of fillRect. We should reduce the number of pixels it draws.
        Obviously, the current method draws less pixels than the second one. So it's optimized already!
	 */
	for (c = start; c <= end; c++) {
		if (c < end) {
			currAttr = (currRow + c)->attr;
			currentBackgroundColor = bgColorIndexOfAttribute(currAttr);
            currentBold = bgBoldOfAttribute(currAttr);
		}
		
		if (currentBackgroundColor != lastBackgroundColor || currentBold != lastBold || c == end) {
			/* Draw Background */
			NSRect rect = NSMakeRect((c - length) * _fontWidth, (gRow - 1 - r) * _fontHeight,
								  _fontWidth * length, _fontHeight);
			
			// Modified by K.O.ed: All background color use same alpha setting.
			NSColor *bgColor = [gConfig colorAtIndex: lastBackgroundColor hilite: lastBold];
			bgColor = [bgColor colorWithAlphaComponent: [[gConfig colorBG] alphaComponent]];
			[bgColor set];
			
			//[[gConfig colorAtIndex: lastBackgroundColor hilite: lastBold] set];
			// [NSBezierPath fillRect: rect];
            NSRectFill(rect);
			
			/* finish this segment */
			length = 1;
			lastAttr.v = currAttr.v;
			lastBackgroundColor = currentBackgroundColor;
            lastBold = currentBold;
		} else {
			length++;
		}
	}
	
	[self setNeedsDisplayInRect: rowRect];
}

- (void) drawSpecialSymbol: (unichar) ch forRow: (int) r column: (int) c leftAttribute: (attribute) attr1 rightAttribute: (attribute) attr2 {
	int colorIndex1 = fgColorIndexOfAttribute(attr1);
	int colorIndex2 = fgColorIndexOfAttribute(attr2);
	NSPoint origin = NSMakePoint(c * _fontWidth, (gRow - 1 - r) * _fontHeight);

	NSAffineTransform *xform = [NSAffineTransform transform]; 
	[xform translateXBy: origin.x yBy: origin.y];
	[xform concat];
	
	if (colorIndex1 == colorIndex2 && fgBoldOfAttribute(attr1) == fgBoldOfAttribute(attr2)) {
		NSColor *color = [gConfig colorAtIndex: colorIndex1 hilite: fgBoldOfAttribute(attr1)];
		
		if (ch == 0x25FC) { // ◼ BLACK SQUARE
			[color set];
			NSRectFill(gSymbolBlackSquareRect);
		} else if (ch >= 0x2581 && ch <= 0x2588) { // BLOCK ▁▂▃▄▅▆▇█
			[color set];
			NSRectFill(gSymbolLowerBlockRect[ch - 0x2581]);
		} else if (ch >= 0x2589 && ch <= 0x258F) { // BLOCK ▉▊▋▌▍▎▏
			[color set];
			NSRectFill(gSymbolLeftBlockRect[ch - 0x2589]);
		} else if (ch >= 0x25E2 && ch <= 0x25E5) { // TRIANGLE ◢◣◤◥
            [color set];
            [gSymbolTrianglePath[ch - 0x25E2] fill];
		} else if (ch == 0x0) {
		}
	} else { // double color
		NSColor *color1 = [gConfig colorAtIndex: colorIndex1 hilite: fgBoldOfAttribute(attr1)];
		NSColor *color2 = [gConfig colorAtIndex: colorIndex2 hilite: fgBoldOfAttribute(attr2)];
		if (ch == 0x25FC) { // ◼ BLACK SQUARE
			[color1 set];
			NSRectFill(gSymbolBlackSquareRect1);
			[color2 set];
			NSRectFill(gSymbolBlackSquareRect2);
		} else if (ch >= 0x2581 && ch <= 0x2588) { // BLOCK ▁▂▃▄▅▆▇█
			[color1 set];
			NSRectFill(gSymbolLowerBlockRect1[ch - 0x2581]);
			[color2 set];
            NSRectFill(gSymbolLowerBlockRect2[ch - 0x2581]);
		} else if (ch >= 0x2589 && ch <= 0x258F) { // BLOCK ▉▊▋▌▍▎▏
			[color1 set];
			NSRectFill(gSymbolLeftBlockRect1[ch - 0x2589]);
            if (ch <= 0x259B) {
                [color2 set];
                NSRectFill(gSymbolLeftBlockRect2[ch - 0x2589]);
            }
		} else if (ch >= 0x25E2 && ch <= 0x25E5) { // TRIANGLE ◢◣◤◥
            [color1 set];
            [gSymbolTrianglePath1[ch - 0x25E2] fill];
            [color2 set];
            [gSymbolTrianglePath2[ch - 0x25E2] fill];
		}
	}
	[xform invert];
	[xform concat];
}

#pragma mark -
#pragma mark Override

- (BOOL) isFlipped {
	return NO;
}

- (BOOL) isOpaque {
	return YES;
}

- (BOOL) acceptsFirstResponder {
	return YES;
}

- (BOOL)canBecomeKeyView {
    return YES;
}
/* commented out by boost @ 9#: why not using the delegate...
- (void)removeTabViewItem:(NSTabViewItem *)tabViewItem {
    [[tabViewItem identifier] close];
    [super removeTabViewItem:tabViewItem];
}
*/
+ (NSMenu *) defaultMenu {
    return [[[NSMenu alloc] init] autorelease];
}

- (NSMenu *) menuForEvent: (NSEvent *) theEvent {
    if (![self connected])
        return nil;
    NSString *s = [self selectedPlainString];
    return [YLContextualMenuManager menuWithSelectedString:s];
}

/* Otherwise, it will return the subview. */
- (NSView *) hitTest: (NSPoint) p {
    return self;
}

#pragma mark -
#pragma mark Accessor

- (int)x {
    return _x;
}

- (void)setX:(int)value {
    _x = value;
}

- (int) y {
    return _y;
}

- (void) setY: (int) value {
    _y = value;
}

- (float) fontWidth {
    return _fontWidth;
}

- (void)setFontWidth:(float)value {
    _fontWidth = value;
}

- (float) fontHeight {
    return _fontHeight;
}

- (void) setFontHeight:(float)value {
    _fontHeight = value;
}

- (BOOL) connected {
	return [[self frontMostConnection] connected];
}

- (YLTerminal *) frontMostTerminal {
    return (YLTerminal *)[[self frontMostConnection] terminal];
}

- (YLConnection *) frontMostConnection {
    id identifier = [[self selectedTabViewItem] identifier];
    return (YLConnection *) identifier;
}

- (NSString *) selectedPlainString {
    if (_selectionLength == 0) return nil;
    int location, length;
    if (_selectionLength >= 0) {
        location = _selectionLocation;
        length = _selectionLength;
    } else {
        location = _selectionLocation + _selectionLength;
        length = 0 - (int)_selectionLength;
    }
    return [[self frontMostTerminal] stringFromIndex: location length: length];
}

- (BOOL) hasBlinkCell {
    int c, r;
    id ds = [self frontMostTerminal];
    if (!ds) return NO;
    for (r = 0; r < gRow; r++) {
        [ds updateDoubleByteStateForRow: r];
        cell *currRow = [ds cellsOfRow: r];
        for (c = 0; c < gColumn; c++) 
            if (isBlinkCell(currRow[c]))
                return YES;
    }
    return NO;
}

#pragma mark -
#pragma mark NSTextInput Protocol
/* NSTextInput protocol */
// instead of keyDown: aString can be NSString or NSAttributedString
- (void)insertText:(id)aString {
    [self insertText:aString withDelay:0];
}

- (void)insertText:(id)aString withDelay:(int)microsecond {
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
    
    [_textField setHidden: YES];
    [_markedText release];
    _markedText = nil;	
	
    [[self frontMostConnection] sendText:aString withDelay:microsecond];

    [pool release];
}

- (void)doCommandBySelector:(SEL)aSelector {
	unsigned char ch[10];
    
//    NSLog(@"%s", aSelector);
    
	if (aSelector == @selector(insertNewline:)) {
		ch[0] = 0x0D;
		[[self frontMostConnection] sendBytes: ch length: 1];
    } else if (aSelector == @selector(cancelOperation:)) {
        ch[0] = 0x1B;
		[[self frontMostConnection] sendBytes: ch length: 1];
//	} else if (aSelector == @selector(cancel:)) {
	} else if (aSelector == @selector(scrollToBeginningOfDocument:)) {
        ch[0] = 0x1B; ch[1] = '['; ch[2] = '1'; ch[3] = '~';
		[[self frontMostConnection] sendBytes: ch length: 4];		
	} else if (aSelector == @selector(scrollToEndOfDocument:)) {
        ch[0] = 0x1B; ch[1] = '['; ch[2] = '4'; ch[3] = '~';
		[[self frontMostConnection] sendBytes: ch length: 4];		
	} else if (aSelector == @selector(scrollPageUp:)) {
		ch[0] = 0x1B; ch[1] = '['; ch[2] = '5'; ch[3] = '~';
		[[self frontMostConnection] sendBytes: ch length: 4];
	} else if (aSelector == @selector(scrollPageDown:)) {
		ch[0] = 0x1B; ch[1] = '['; ch[2] = '6'; ch[3] = '~';
		[[self frontMostConnection] sendBytes: ch length: 4];		
	} else if (aSelector == @selector(insertTab:)) {
        ch[0] = 0x09;
		[[self frontMostConnection] sendBytes: ch length: 1];
    } else if (aSelector == @selector(deleteForward:)) {
		ch[0] = 0x1B; ch[1] = '['; ch[2] = '3'; ch[3] = '~';
		ch[4] = 0x1B; ch[5] = '['; ch[6] = '3'; ch[7] = '~';
        int len = 4;
        id ds = [self frontMostTerminal];
        if ([[[self frontMostConnection] site] detectDoubleByte] && 
            [ds cursorColumn] < (gColumn - 1) && 
            [ds attrAtRow: [ds cursorRow] column: [ds cursorColumn] + 1].f.doubleByte == 2)
            len += 4;
        [[self frontMostConnection] sendBytes: ch length: len];
    } else {
        NSLog(@"Unprocessed selector: %s", aSelector);
    }
}

// setMarkedText: cannot take a nil first argument. aString can be NSString or NSAttributedString
- (void) setMarkedText:(id)aString selectedRange:(NSRange)selRange {
    YLTerminal *ds = [self frontMostTerminal];
	if (![aString respondsToSelector: @selector(isEqualToAttributedString:)] && [aString isMemberOfClass: [NSString class]])
		aString = [[[NSAttributedString alloc] initWithString: aString] autorelease];

	if ([aString length] == 0) {
		[self unmarkText];
		return;
	}
	
	if (_markedText != aString) {
		[_markedText release];
		_markedText = [aString retain];
	}
	_selectedRange = selRange;
	_markedRange.location = 0;
	_markedRange.length = [aString length];
		
	[_textField setString: aString];
	[_textField setSelectedRange: selRange];
	[_textField setMarkedRange: _markedRange];

	NSPoint o = NSMakePoint(ds->_cursorX * _fontWidth, (gRow - 1 - ds->_cursorY) * _fontHeight + 5.0);
	CGFloat dy;
	if (o.x + [_textField frame].size.width > gColumn * _fontWidth) 
		o.x = gColumn * _fontWidth - [_textField frame].size.width;
	if (o.y + [_textField frame].size.height > gRow * _fontHeight) {
		o.y = (gRow - ds->_cursorY) * _fontHeight - 5.0 - [_textField frame].size.height;
		dy = o.y + [_textField frame].size.height;
	} else {
		dy = o.y;
	}
	[_textField setFrameOrigin: o];
	[_textField setDestination: [_textField convertPoint: NSMakePoint((ds->_cursorX + 0.5) * _fontWidth, dy)
												fromView: self]];
	[_textField setHidden: NO];
}

- (void)unmarkText {
    [_markedText release];
    _markedText = nil;
    [_textField setHidden: YES];
}

- (BOOL)hasMarkedText {
    return (_markedText != nil);
}

- (NSInteger)conversationIdentifier {
    return (NSInteger)self;
}

// Returns attributed string at the range.  This allows input mangers to query any range in backing-store.  May return nil.
- (NSAttributedString *)attributedSubstringFromRange:(NSRange)theRange {
    if (theRange.location < 0 || theRange.location >= [_markedText length]) return nil;
    if (theRange.location + theRange.length > [_markedText length]) 
        theRange.length = [_markedText length] - theRange.location;
    return [[[NSAttributedString alloc] initWithString:[[_markedText string] substringWithRange:theRange]] autorelease];
}

// This method returns the range for marked region.  If hasMarkedText == false, it'll return NSNotFound location & 0 length range.
- (NSRange)markedRange {
    return _markedRange;
}

// This method returns the range for selected region.  Just like markedRange method, its location field contains char index from the text beginning.
- (NSRange)selectedRange {
    return _selectedRange;
}

// This method returns the first frame of rects for theRange in screen coordindate system.
- (NSRect)firstRectForCharacterRange:(NSRange)theRange {
    NSPoint pointInWindowCoordinates;
    NSRect rectInScreenCoordinates;

    pointInWindowCoordinates = [_textField frame].origin;
    //[_textField convertPoint: [_textField frame].origin toView: nil];
    rectInScreenCoordinates.origin = [[_textField window] convertBaseToScreen: pointInWindowCoordinates];
    rectInScreenCoordinates.size = [_textField bounds].size;

    return rectInScreenCoordinates;
}

// This method returns the index for character that is nearest to thePoint.  thPoint is in screen coordinate system.
- (NSUInteger)characterIndexForPoint:(NSPoint)thePoint {
    return 0;
}

// This method is the key to attribute extension.  We could add new attributes through this method. NSInputServer examines the return value of this method & constructs appropriate attributed string.
- (NSArray*)validAttributesForMarkedText {
    return [NSArray array];
}

#pragma mark -
#pragma mark Url Menu
- (BOOL) isInUrlState {
	return _isInUrlMode;
}

#pragma mark -
#pragma mark Portal
- (BOOL) isInPortalState {
	return _isInPortalMode;
}
// Show the portal, initiallize it if necessary
- (void)updatePortal {
	if(_portal) {
	} else {
		_portal = [[XIPortal alloc] initWithView: self];
		[_portal setFrame:[self frame]];
	}
	[_effectView clear];
	[self clearAllTrackingArea];
	[self addSubview:_portal];
	_isInPortalMode = YES;
}
// Remove current portal
- (void)removePortal {
	//if(_portal) {
		[_portal removeFromSuperview];
		[_portal release];
		_portal = nil;
	//}
	_isInPortalMode = NO;
}
// Reset a new portal
- (void)resetPortal {
	// Remove it at first...
	if(_isInPortalMode)
		if(_portal)
			[_portal removeFromSuperview];
	[_portal release];
	_portal = nil;
	// Update the new portal if necessary...
	if(_isInPortalMode) {
		[self updatePortal];
	}
}
// Set the portal in right state...
- (void)checkPortal {
	if(![[[self frontMostConnection] site] empty] && _isInPortalMode) {
		[self removePortal];
	}
	else if([[[self frontMostConnection] site] empty] && !_isInPortalMode) {
		[self updatePortal];
	}
}

- (void)addPortalPicture: (NSString *) source 
				 forSite: (NSString *) siteName {
	NSFileManager *fileManager = [NSFileManager defaultManager];
	
	// Create the dir if necessary
	// by gtCarrera
	NSString *destDir = [[[NSHomeDirectory() stringByAppendingPathComponent:@"Library"]
						  stringByAppendingPathComponent:@"Application Support"]
						 stringByAppendingPathComponent:@"Welly"];
	[fileManager createDirectoryAtPath:destDir attributes:nil];
	destDir = [destDir stringByAppendingPathComponent:@"Covers"];
	[fileManager createDirectoryAtPath:destDir attributes:nil];
	
	NSString *destination = [destDir stringByAppendingPathComponent:siteName];
	// Ends here
	
	// Remove all existing picture for this site
	NSArray *allowedTypes = [NSArray arrayWithObjects:@"jpg", @"jpeg", @"bmp", @"png", @"gif", @"tiff", @"tif", nil];
	for (NSString *ext in allowedTypes) {
		[fileManager removeItemAtPath:[destination stringByAppendingPathExtension:ext] error:NULL];
	}
	[fileManager copyItemAtPath:source toPath:[destination stringByAppendingPathExtension:[source pathExtension]] error:NULL];
}

#pragma mark -
#pragma mark Hot Spots;
- (void)refreshAllHotSpots {
	// Clear it...
	[self clearAllTrackingArea];
	[self discardCursorRects];
	// For default hot spots
	if(![[self frontMostConnection] connected])
		return;
	for(int y = 0; y < gRow; y++)
		[self updateIPStateForRow: y];
	// Set the cursor for writting texts
	// I don't know why the cursor cannot change the first time
	if ([[self frontMostTerminal] bbsState].state == BBSComposePost) 
		[gMoveCursor set];
	else
		[NSCursor pop];
	// For the mouse preference
	if (![[[self frontMostConnection] site] enableMouse]) 
		return;
	for (int y = 0; y < gRow; y++) {
		[self updateClickEntryForRow: y];
		[self updateButtonAreaForRow: y];
	}
	[self updateExitArea];
	[self updatePageUpArea];
	[self updatePageDownArea];
}

#pragma mark ip seeker
- (void)addIPRect: (const char *)ip
			  row: (int)r
		   column: (int)c
		   length: (int)length {
	/* ip tooltip */
	NSRect rect = NSMakeRect(c * _fontWidth, (gRow - 1 - r) * _fontHeight,
							 _fontWidth * length, _fontHeight);
	NSString *tooltip = [[IPSeeker shared] getLocation:ip];
	[self addToolTip: tooltip row:r column:c length:length];
	// Here we use an mutable array to store the ref of tracking rect data
	// Just for the f**king [NSView removeTrackingRect] which cannot release
	// user data
	KOTrackingRectData * data = [KOTrackingRectData ipRectData:[NSString stringWithFormat: @"%d.%d.%d.%d", ip[0], ip[1], ip[2], ip[3]]
													   toolTip:tooltip];
	[_trackingRectDataList addObject:data];
	NSTrackingRectTag rectTag = [self addTrackingRect: rect
												owner: self
											 userData: data
										 assumeInside: YES];
	[_ipTrackingRects push_back: rectTag];
}

- (void)addToolTip: (NSString *)tooltip
			   row: (int)r
			column: (int)c
			length: (int)length {
	/* ip tooltip */
	NSRect rect = NSMakeRect(c * _fontWidth, (gRow - 1 - r) * _fontHeight,
							 _fontWidth * length, _fontHeight);
	[self addToolTipRect: rect owner: self userData: tooltip];
}

- (void)updateIPStateForRow: (int) r {
	cell *currRow = [[self frontMostTerminal] cellsOfRow: r];
	int state = 0;
	char ip[4] = {0};
	int seg = 0;
	int start = 0, length = 0;
	for (int i = 0; i < gColumn; i++) {
		unsigned char b = currRow[i].byte;
		switch (state) {
			case 0:
				if (b >= '0' && b <= '9') { // numeric, beginning of an ip
					start = i;
					length = 1;
					ip[0] = ip[1] = ip[2] = ip[3];
					seg = b - '0';
					state = 1;
				}
				break;
			case 1:
			case 2:
			case 3:
				if (b == '.') {	// segment ended
					if (seg > 255) {	// invalid number
						state = 0;
						break;
					}
					// valid number
					ip[state-1] = seg & 0xff;
					seg = 0;
					state++;
					length++;
				} else if (b >= '0' && b <= '9') {	// continue to be numeric
					seg = seg * 10 + (b - '0');
					length++;
				} else {	// invalid character
					state = 0;
					break;
				}
				break;
            case 4:
                if (b >= '0' && b <= '9') {	// continue to be numeric
                    seg = seg * 10 + (b - '0');
                    length++;
                } else {	// non-numeric, then the string should be finished.
                    if (b == '*') // for ip address 255.255.255.*
                        ++length;
                    if (seg < 255) {	// available ip
                        ip[state-1] = seg & 255;
                        [self addIPRect:ip row:r column:start length:length];
                    }
                    state = 0;
                }
                break;
			default:
				break;
		}
	}
}

#pragma mark Remove All Tracking Rects
/*
 * clear all tracking rects
 */
- (void)clearAllTrackingArea {
	[_effectView clear];
	// remove all tool tips
	[self removeAllToolTips];
	// Release all tracking rect data
	while ([_trackingRectDataList count] != 0) {
		KOTrackingRectData * rectData = (KOTrackingRectData*)[_trackingRectDataList lastObject];
		[_trackingRectDataList removeLastObject];
		[rectData release];
	}
	// remove all ip tracking rects
	while(![_ipTrackingRects empty]) {
		NSTrackingRectTag rectTag = (NSTrackingRectTag)[_ipTrackingRects front];
		[self removeTrackingRect:rectTag];
		[_ipTrackingRects pop_front];
	}
	
	while(![_clickEntryTrackingRects empty]) {
		NSTrackingRectTag rectTag = (NSTrackingRectTag)[_clickEntryTrackingRects front];
		[self removeTrackingRect:rectTag];
		[_clickEntryTrackingRects pop_front];
	}
	
	while(![_buttonTrackingRects empty]) {
		NSTrackingRectTag rectTag = (NSTrackingRectTag)[_buttonTrackingRects front];
		[self removeTrackingRect:rectTag];
		[_buttonTrackingRects pop_front];
	}

	_clickEntryData = nil;
	_buttonData = nil;
	// Remove the tracking rect for exit, pgup and pgdown
	[self removeTrackingRect:_exitTrackingRect];
	[self removeTrackingRect:_pgUpTrackingRect];
	[self removeTrackingRect:_pgDownTrackingRect];
	_exitTrackingRect = 0;
	_pgUpTrackingRect = 0;
	_pgDownTrackingRect = 0;
	//_isMouseInExitArea = NO;
}

#pragma mark Post Entry Point
- (void)addClickEntryRect: (NSString *)title
					  row: (int)r
				   column: (int)c
				   length: (int)length {
	/* ip tooltip */
	NSRect rect = [self rectAtRow:r column:c height:1 width:length];
	//NSMakeRect(c * _fontWidth, (gRow - 1 - r) * _fontHeight, _fontWidth * length, _fontHeight);
	KOTrackingRectData * data = [KOTrackingRectData clickEntryRectData: title
																 atRow: r];
	[_trackingRectDataList addObject:data];
	NSTrackingRectTag rectTag = [self addTrackingRect: rect
												owner: self
											 userData: data
										 assumeInside: YES];
	[_clickEntryTrackingRects push_back: rectTag];
}

- (void)addClickEntryRectAtRow:(int)r column:(int)c length:(int)length {
    NSString *title = [[self frontMostTerminal] stringFromIndex:c+r*gColumn length:length];
    [self addClickEntryRect:title row:r column:c length:length];
}

- (BOOL)startsAtRow:(int)row column:(int)column with:(NSString *)s {
    cell *currRow = [[self frontMostTerminal] cellsOfRow:row];
    int i = 0, n = [s length];
    for (; i < n && column < gColumn - 1; ++i, ++column)
        if (currRow[column].byte != [s characterAtIndex:i])
            return NO;
    if (i != n)
        return NO;
    return YES;
}

- (void)addMainMenuClickEntry: (NSString *)cmd 
						  row: (int)r
					   column: (int)c 
					   length: (int)len {
	NSRect rect = [self rectAtRow:r column:c height:1 width:len];
	KOTrackingRectData * data = [KOTrackingRectData mainMenuClickEntryRectData:cmd];
	[_trackingRectDataList addObject:data];
	NSTrackingRectTag rectTag = [self addTrackingRect: rect
												owner: self
											 userData: data
										 assumeInside: YES];
	[_clickEntryTrackingRects push_back: rectTag];
}

- (void) updateClickEntryForRow: (int) r {
    YLTerminal *ds = [self frontMostTerminal];
    cell *currRow = [ds cellsOfRow:r];
    if ([ds bbsState].state == BBSBrowseBoard || [ds bbsState].state == BBSMailList) {
        // browsing a board
		// header/footer
		if (r < 3 || r == gRow - 1)
			return;
		
		int start = -1, end = -1;
		unichar textBuf[gColumn + 1];
		int bufLength = 0;
    
        // don't check the first two columns ("●" may be used as cursor)
        for (int i = 2; i < gColumn - 1; ++i) {
			int db = currRow[i].attr.f.doubleByte;
			if (db == 0) {
                if (start == -1) {
                    if ([self startsAtRow:r column:i with:@"Re: "] || // smth
                        [self startsAtRow:r column:i with:@"R: "])    // ptt
                        start = i;
                }
				if (currRow[i].byte > 0 && currRow[i].byte != ' ')
					end = i;
                if (start != -1)
                    textBuf[bufLength++] = 0x0000 + (currRow[i].byte ?: ' ');
            } else if (db == 2) {
				unsigned short code = (((currRow + i - 1)->byte) << 8) + ((currRow + i)->byte) - 0x8000;
				unichar ch = [[[self frontMostConnection] site] encoding] == YLBig5Encoding ? B2U[code] : G2U[code];
                // smth: 0x25cf (solid circle "●"), 0x251c ("├"), 0x2514 ("└"), 0x2605("★")
                // free/sjtu: 0x25c6 (solid diamond "◆")
                // ptt: 0x25a1 (hollow square "□")
                if (start == -1 && ch >= 0x2510 && ch <= 0x260f)
					start = i - 1;
				end = i;
				if (start != -1)
					textBuf[bufLength++] = ch;
			}
		}
		
		if (start == -1)
			return;
		
		[self addClickEntryRect: [NSString stringWithCharacters:textBuf length:bufLength]
							row: r
						 column: start
						 length: end - start + 1];
		
	} else if ([ds bbsState].state == BBSBoardList) {
        // watching board list
		// header/footer
		if (r < 3 || r == gRow - 1)
			return;
		
        // TODO: fix magic numbers
        if (currRow[12].byte != 0 && currRow[12].byte != ' ' && (currRow[11].byte == ' ' || currRow[11].byte == '*'))
            [self addClickEntryRectAtRow:r column:12 length:80-28]; // smth
        else if (currRow[10].byte != 0 && currRow[10].byte != ' ' && currRow[7].byte == ' ')
            [self addClickEntryRectAtRow:r column:10 length:80-26]; // ptt
        else if (currRow[10].byte != 0 && currRow[10].byte != ' ' && (currRow[9].byte == ' ' || currRow[9].byte == '-') && currRow[30].byte == ' ')
            [self addClickEntryRectAtRow:r column:10 length:80-23]; // lqqm
        else if (currRow[10].byte != 0 && currRow[10].byte != ' ' && (currRow[9].byte == ' ' || currRow[9].byte == '-') && currRow[31].byte == ' ')
            [self addClickEntryRectAtRow:r column:10 length:80-30]; // zju88
    } else if ([ds bbsState].state == BBSFriendList) {
		// header/footer
		if (r < 3 || r == gRow - 1)
			return;
		
        // TODO: fix magic numbers
        if (currRow[7].byte == 0 || currRow[7].byte == ' ')
            return;
        [self addClickEntryRectAtRow:r column:7 length:80-13];
	} else if ([ds bbsState].state == BBSMainMenu || [ds bbsState].state == BBSMailMenu) {
		// main menu
		if (r < 3 || r == gRow - 1)
			return;
		/*
		const int ST_START = 0;
		const int ST_BRACKET_FOUND = 1;
		const int ST_SPACE_FOUND = 2;
		const int ST_NON_SPACE_FOUND = 3;
		*/
		enum {
			ST_START, ST_BRACKET_FOUND, ST_SPACE_FOUND, ST_NON_SPACE_FOUND, ST_SINGLE_SPACE_FOUND
		};
		
		int start = -1, end = -1;
		int state = ST_START;
		char shortcut = 0;
		
        // don't check the first two columns ("●" may be used as cursor)
        for (int i = 2; i < gColumn - 2; ++i) {
			int db = currRow[i].attr.f.doubleByte;
			switch (state) {
				case ST_START:
					if (currRow[i].byte == ')' && isalnum(currRow[i-1].byte)) {
						start = (currRow[i-2].byte == '(')? i-2: i-1;
						end = start;
						state = ST_BRACKET_FOUND;
						shortcut = currRow[i-1].byte;
					}
					break;
				case ST_BRACKET_FOUND:
					end = i;/*
					if (currRow[i].byte == ' ') {
						state = ST_SPACE_FOUND;
					}*/
					if (db == 1) {
						state = ST_NON_SPACE_FOUND;
					}
					break;
					/*
				case ST_SPACE_FOUND:
					end = i;
					if (currRow[i].byte != ' ')
						state = ST_NON_SPACE_FOUND;
					break;*/
				case ST_NON_SPACE_FOUND:
					if (currRow[i].byte == ' ' || currRow[i].byte == 0) {
						state = ST_SINGLE_SPACE_FOUND;
					} else {
						end = i;
					}
					break;
				case ST_SINGLE_SPACE_FOUND:
					if (currRow[i].byte == ' ' || currRow[i].byte == 0) {
						state = ST_START;
						[self addMainMenuClickEntry:[NSString stringWithFormat:@"%c\n", shortcut] 
												row:r
											 column:start
											 length:end - start + 1];
						start = i;
						end = i;
					} else {
						state = ST_NON_SPACE_FOUND;
						end = i;
					}
					break;
				default:
					break;
			}
		}
	}
}

#pragma mark Exit Area

- (void)addExitAreaAtRow: (int)r 
				  column: (int)c 
				  height: (int)h 
				   width: (int)w {
	//NSLog(@"Exit Area added");	
	if (_exitTrackingRect)
		return;
	NSRect rect = [self rectAtRow:r	column:c height:h width:w];
	[self addCursorRect:rect cursor:[NSCursor resizeLeftCursor]];
	//NSLog(@"new Exit area");
	//if (_exitTrackingRect)
	//	[self removeTrackingRect: _exitTrackingRect];
	KOTrackingRectData * data = [KOTrackingRectData exitRectData];
	[_trackingRectDataList addObject:data];
	_exitTrackingRect = [self addTrackingRect: rect
										owner: self
									 userData: data
								 assumeInside: YES];
	//NSLog(@"Exit Area added!");
}

- (void)removeExitArea {
	if (!_exitTrackingRect) {
		//NSLog(@"No exit area!");
		return;
	}
	//[[self window] invalidateCursorRectsForView: self];
	//NSRect rect = [self rectAtRow:3	column:0 height:20 width:7];
	//[self removeCursorRect: rect cursor:[NSCursor resizeLeftCursor]];
	//[self addCursorRect:[self frame] cursor:_normalCursor];
	[self removeTrackingRect: _exitTrackingRect];
	//NSLog(@"Exit area removed");
	//_exitTrackingRect = -1;
}

- (void)updateExitArea {
	YLTerminal *ds = [self frontMostTerminal];
	if ([ds bbsState].state == BBSComposePost) {
		[self removeExitArea];
	} else {
		[self addExitAreaAtRow:3 
						column:0 
						height:20
						 width:20];
	}
}

#pragma mark pgUp/Down Area

- (void)addPageUpAreaAtRow: (int)r 
					column: (int)c 
					height: (int)h 
					 width: (int)w {
	NSRect rect = [self rectAtRow:r	column:c height:h width:w];
	[self addCursorRect:rect cursor:[NSCursor resizeUpCursor]];
	if (_pgUpTrackingRect)
		return;
	KOTrackingRectData * data = [KOTrackingRectData pgUpRectData];
	[_trackingRectDataList addObject:data];
	_pgUpTrackingRect = [self addTrackingRect: rect
										owner: self
									 userData: data
								 assumeInside: YES];
}

- (void)updatePageUpArea {
	YLTerminal *ds = [self frontMostTerminal];
	if ([ds bbsState].state == BBSBoardList 
		|| [ds bbsState].state == BBSBrowseBoard
		|| [ds bbsState].state == BBSFriendList
		|| [ds bbsState].state == BBSMailList
		|| [ds bbsState].state == BBSViewPost) {
			[self addPageUpAreaAtRow:0
							  column:20
							  height:[[YLLGlobalConfig sharedInstance] row] / 2
							   width:[[YLLGlobalConfig sharedInstance] column] - 20];
	} else {
		if(_pgUpTrackingRect) {
			[self removeTrackingRect: _pgUpTrackingRect];
			[NSCursor pop];
		}
	}
}

- (void)addPageDownAreaAtRow: (int)r 
					column: (int)c 
					height: (int)h 
					 width: (int)w {
	NSRect rect = [self rectAtRow:r	column:c height:h width:w];
	[self addCursorRect:rect cursor:[NSCursor resizeDownCursor]];
	if (_pgDownTrackingRect)
		return;
	KOTrackingRectData * data = [KOTrackingRectData pgDownRectData];
	[_trackingRectDataList addObject:data];
	_pgDownTrackingRect = [self addTrackingRect: rect
										owner: self
									 userData: data
								 assumeInside: YES];
}

- (void)updatePageDownArea {
	YLTerminal *ds = [self frontMostTerminal];
	if ([ds bbsState].state == BBSBoardList 
		|| [ds bbsState].state == BBSBrowseBoard
		|| [ds bbsState].state == BBSFriendList
		|| [ds bbsState].state == BBSMailList
		|| [ds bbsState].state == BBSViewPost) {
		[self addPageDownAreaAtRow:[[YLLGlobalConfig sharedInstance] row] / 2
						  column:20
						  height:[[YLLGlobalConfig sharedInstance] row] / 2
						   width:[[YLLGlobalConfig sharedInstance] column] - 20];
	} else {
		if(_pgDownTrackingRect) {
			[self removeTrackingRect: _pgDownTrackingRect];
			[NSCursor pop];
		}
	}
}

#pragma mark button Area
- (void) addButtonArea: (KOButtonType)buttonType 
	   commandSequence: (NSString *)cmd 
				 atRow: (int)r 
				column: (int)c 
				length: (int)len {
	NSRect rect = [self rectAtRow:r column:c height:1 width:len];
	KOTrackingRectData * data = [KOTrackingRectData buttonRectData:buttonType
												   commandSequence:cmd];
	[_trackingRectDataList addObject:data];
	NSTrackingRectTag rectTag = [self addTrackingRect: rect
												owner: self
											 userData: data
										 assumeInside: YES];
	[_buttonTrackingRects push_back: rectTag];
}

- (void) updateButtonAreaForRow:(int)r {
	YLTerminal *ds = [self frontMostTerminal];
	//cell *currRow = [ds cellsOfRow: r];
	if ([ds bbsState].state == BBSBrowseBoard) {
		for (int x = 0; x < gColumn; ++x) {
			if (x < gColumn - 16 && [[ds stringFromIndex:(x + r * gColumn) length:16] isEqualToString:@"发表文章[Ctrl-P]"]) {
				[self addButtonArea:COMPOSE_POST commandSequence:fbComposePost atRow:r column:x length:16];
				x += 15;
				continue;
			}
			if (x < gColumn - 7 && [[ds stringFromIndex:(x + r * gColumn) length:7] isEqualToString:@"砍信[d]"]) {
				[self addButtonArea:DELETE_POST commandSequence:fbDeletePost atRow:r column:x length:7];
				x += 6;
				continue;
			}
			if (x < gColumn - 11 && [[ds stringFromIndex:(x + r * gColumn) length:11] isEqualToString:@"备忘录[TAB]"]) {
				[self addButtonArea:SHOW_NOTE commandSequence:fbShowNote atRow:r column:x length:11];
				x += 10;
				continue;
			}
			if (x < gColumn - 7 && [[ds stringFromIndex:(x + r * gColumn) length:7] isEqualToString:@"求助[h]"]) {
				[self addButtonArea:SHOW_HELP commandSequence:fbShowHelp atRow:r column:x length:7];
				x += 6;
				continue;
			}
			if (x < gColumn - 10 && [[ds stringFromIndex:(x + r * gColumn) length:10] isEqualToString:@"[一般模式]"]) {
				[self addButtonArea:NORMAL_TO_DIGEST commandSequence:fbNormalToDigest atRow:r column:x length:10];
				x += 9;
				continue;
			}
			if (x < gColumn - 10 && [[ds stringFromIndex:(x + r * gColumn) length:10] isEqualToString:@"[文摘模式]"]) {
				[self addButtonArea:DIGEST_TO_THREAD commandSequence:fbDigestToThread atRow:r column:x length:10];
				x += 9;
				continue;
			}
			if (x < gColumn - 10 && [[ds stringFromIndex:(x + r * gColumn) length:10] isEqualToString:@"[主题模式]"]) {
				[self addButtonArea:THREAD_TO_MARK commandSequence:fbThreadToMark atRow:r column:x length:10];
				x += 9;
				continue;
			}
			if (x < gColumn - 10 && [[ds stringFromIndex:(x + r * gColumn) length:10] isEqualToString:@"[精华模式]"]) {
				[self addButtonArea:MARK_TO_ORIGIN commandSequence:fbMarkToOrigin atRow:r column:x length:10];
				x += 9;
				continue;
			}
			if (x < gColumn - 10 && [[ds stringFromIndex:(x + r * gColumn) length:10] isEqualToString:@"[原作模式]"]) {
				[self addButtonArea:ORIGIN_TO_NORMAL commandSequence:fbOriginToNormal atRow:r column:x length:10];
				x += 9;
				continue;
			}
		}
	}
}

#pragma mark -
#pragma mark safe_paste

- (void)confirmPaste:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo {
    if (returnCode == NSAlertDefaultReturn) {
		[self performPaste];
    }
}

- (void)confirmPasteWrap:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo {
    if (returnCode == NSAlertDefaultReturn) {
		[self performPasteWrap];
    }
}

- (void)confirmPasteColor:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo {
    if (returnCode == NSAlertDefaultReturn) {
		[self performPasteColor];
    }
}

- (void)performPaste {
	NSPasteboard *pb = [NSPasteboard generalPasteboard];
	NSArray *types = [pb types];
	if ([types containsObject: NSStringPboardType]) {
		NSString *str = [pb stringForType: NSStringPboardType];
		[self insertText: str withDelay: 100];
	}
}

- (void)performPasteWrap {
	NSPasteboard *pb = [NSPasteboard generalPasteboard];
	NSArray *types = [pb types];
	if (![types containsObject:NSStringPboardType]) return;
	
	NSString *str = [pb stringForType:NSStringPboardType];
	int i, j, LINE_WIDTH = 66, LPADDING = 4;
	XIIntegerArray *word = [XIIntegerArray integerArray],
	*text = [XIIntegerArray integerArray];
	int word_width = 0, line_width = 0;
	[text push_back:0x000d];
	for (i = 0; i < LPADDING; i++)
		[text push_back:0x0020];
	line_width = LPADDING;
	for (i = 0; i < [str length]; i++) {
		unichar c = [str characterAtIndex: i];
		if (c == 0x0020 || c == 0x0009) { // space
			for (j = 0; j < [word size]; j++)
				[text push_back:[word at:j]];
			[word clear];
			line_width += word_width;
			word_width = 0;
			if (line_width >= LINE_WIDTH + LPADDING) {
				[text push_back:0x000d];
				for (j = 0; j < LPADDING; j++)
					[text push_back:0x0020];
				line_width = LPADDING;
			}
			int repeat = (c == 0x0020) ? 1 : 4;
			for (j = 0; j < repeat ; j++)
				[text push_back:0x0020];
			line_width += repeat;
		} else if (c == 0x000a || c == 0x000d) {
			for (j = 0; j < [word size]; j++)
				[text push_back:[word at:j]];
			[word clear];
			[text push_back:0x000d];
			//            [text push_back:0x000d];
			for (j = 0; j < LPADDING; j++)
				[text push_back:0x0020];
			line_width = LPADDING;
			word_width = 0;
		} else if (c > 0x0020 && c < 0x0100) {
			[word push_back:c];
			word_width++;
			if (c >= 0x0080) word_width++;
		} else if (c >= 0x1000){
			for (j = 0; j < [word size]; j++)
				[text push_back:[word at:j]];
			[word clear];
			line_width += word_width;
			word_width = 0;
			if (line_width >= LINE_WIDTH + LPADDING) {
				[text push_back:0x000d];
				for (j = 0; j < LPADDING; j++)
					[text push_back:0x0020];
				line_width = LPADDING;
			}
			[text push_back:c];
			line_width += 2;
		} else {
			[word push_back:c];
		}
		if (line_width + word_width > LINE_WIDTH + LPADDING) {
			[text push_back:0x000d];
			for (j = 0; j < LPADDING; j++)
				[text push_back:0x0020];
			line_width = LPADDING;
		}
		if (word_width > LINE_WIDTH) {
			int acc_width = 0;
			while (![word empty]) {
				int w = ([word front] < 0x0080) ? 1 : 2;
				if (acc_width + w <= LINE_WIDTH) {
					[text push_back:[word front]];
					acc_width += w;
					[word pop_front];
				} else {
					[text push_back:0x000d];
					for (j = 0; j < LPADDING; j++)
						[text push_back:0x0020];
					line_width = LPADDING;
					word_width -= acc_width;
				}
			}
		}
	}
	while (![word empty]) {
		[text push_back:[word front]];
		[word pop_front];
	}
	unichar *carray = (unichar *)malloc(sizeof(unichar) * [text size]);
	for (i = 0; i < [text size]; i++)
		carray[i] = [text at:i];
	NSString *mStr = [NSString stringWithCharacters:carray length:[text size]];
	free(carray);
	[self insertText:mStr withDelay:100];		
}

- (void)performPasteColor {
	NSPasteboard *pb = [NSPasteboard generalPasteboard];
	NSArray *types = [pb types];
	if (![types containsObject: ANSIColorPBoardType]) {
		[self performPaste];
		return;
	}
	
	NSData *escData;
	YLSite *s = [[self frontMostConnection] site];
	if ([s ansiColorKey] == YLCtrlUANSIColorKey) {
		escData = [NSData dataWithBytes: "\x15" length: 1];
	} else if ([s ansiColorKey] == YLEscEscEscANSIColorKey) {
		escData = [NSData dataWithBytes: "\x1B\x1B" length: 2];
	} else {
		escData = [NSData dataWithBytes: "\x1B" length:1];
	}
	
	cell *buffer = (cell *) [[pb dataForType: ANSIColorPBoardType] bytes];
	int bufferLength = [[pb dataForType: ANSIColorPBoardType] length] / sizeof(cell);
	
	attribute defaultANSI;
	defaultANSI.f.bgColor = gConfig->_bgColorIndex;
	defaultANSI.f.fgColor = gConfig->_fgColorIndex;
	defaultANSI.f.blink = 0;
	defaultANSI.f.bold = 0;
	defaultANSI.f.underline = 0;
	defaultANSI.f.reverse = 0;
	
	attribute previousANSI = defaultANSI;
	NSMutableData *writeBuffer = [NSMutableData data];
	
	int i;
	for (i = 0; i < bufferLength; i++) {
		if (buffer[i].byte == '\n' ) {
			previousANSI = defaultANSI;
			[writeBuffer appendData: escData];
			[writeBuffer appendBytes: "[m\r" length: 3];
			continue;
		}
		
		attribute currentANSI = buffer[i].attr;
		
		char tmp[100];
		tmp[0] = '\0';
		
		/* Unchanged */
		if ((currentANSI.f.blink == previousANSI.f.blink) &&
			(currentANSI.f.bold == previousANSI.f.bold) &&
			(currentANSI.f.underline == previousANSI.f.underline) &&
			(currentANSI.f.reverse == previousANSI.f.reverse) &&
			(currentANSI.f.bgColor == previousANSI.f.bgColor) &&
			(currentANSI.f.fgColor == previousANSI.f.fgColor)) {
			[writeBuffer appendBytes: &(buffer[i].byte) length: 1];
			continue;
		}
		
		/* Clear */        
		if ((currentANSI.f.blink == 0 && previousANSI.f.blink == 1) ||
			(currentANSI.f.bold == 0 && previousANSI.f.bold == 1) ||
			(currentANSI.f.underline == 0 && previousANSI.f.underline == 1) ||
			(currentANSI.f.reverse == 0 && previousANSI.f.reverse == 1) ||
			(currentANSI.f.bgColor ==  gConfig->_bgColorIndex && previousANSI.f.reverse != gConfig->_bgColorIndex) ) {
			strcpy(tmp, "[0");
			if (currentANSI.f.blink == 1) strcat(tmp, ";5");
			if (currentANSI.f.bold == 1) strcat(tmp, ";1");
			if (currentANSI.f.underline == 1) strcat(tmp, ";4");
			if (currentANSI.f.reverse == 1) strcat(tmp, ";7");
			if (currentANSI.f.fgColor != gConfig->_fgColorIndex) sprintf(tmp, "%s;%d", tmp, currentANSI.f.fgColor + 30);
			if (currentANSI.f.bgColor != gConfig->_bgColorIndex) sprintf(tmp, "%s;%d", tmp, currentANSI.f.bgColor + 40);
			strcat(tmp, "m");
			[writeBuffer appendData: escData];
			[writeBuffer appendBytes: tmp length: strlen(tmp)];
			[writeBuffer appendBytes: &(buffer[i].byte) length: 1];
			previousANSI = currentANSI;
			continue;
		}
		
		/* Add attribute */
		strcpy(tmp, "[");
		if (currentANSI.f.blink == 1 && previousANSI.f.blink == 0) strcat(tmp, "5;");
		if (currentANSI.f.bold == 1 && previousANSI.f.bold == 0) strcat(tmp, "1;");
		if (currentANSI.f.underline == 1 && previousANSI.f.underline == 0) strcat(tmp, "4;");
		if (currentANSI.f.reverse == 1 && previousANSI.f.reverse == 0) strcat(tmp, "7;");
		if (currentANSI.f.fgColor != previousANSI.f.fgColor) sprintf(tmp, "%s%d;", tmp, currentANSI.f.fgColor + 30);
		if (currentANSI.f.bgColor != previousANSI.f.bgColor) sprintf(tmp, "%s%d;", tmp, currentANSI.f.bgColor + 40);
		tmp[strlen(tmp) - 1] = 'm';
		sprintf(tmp, "%s%c", tmp, buffer[i].byte);
		[writeBuffer appendData: escData];
		[writeBuffer appendBytes: tmp length: strlen(tmp)];
		previousANSI = currentANSI;
		continue;
	}
	[writeBuffer appendData: escData];
	[writeBuffer appendBytes: "[m" length: 2];
	unsigned char *buf = (unsigned char *)[writeBuffer bytes];
	for (i = 0; i < [writeBuffer length]; i++) {
		[[self frontMostConnection] sendBytes: buf + i length: 1];
		usleep(100);
	}
}

#pragma mark -
#pragma mark Test for effect views
- (KOEffectView *) getEffectView {
	return _effectView;
}

/*
#pragma mark -
#pragma mark Drag & Drop
- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender
{
	// Need the delegate hooked up to accept the dragged item(s) into the model
	if ([self delegate]==nil)
	{
		return NSDragOperationNone;
	}
	
	if ([[[sender draggingPasteboard] types] containsObject:NSFilenamesPboardType])
	{
		return NSDragOperationCopy;
	}
	
	return NSDragOperationNone;
}

// Work around a bug from 10.2 onwards
- (unsigned int)draggingSourceOperationMaskForLocal:(BOOL)isLocal
{
	return NSDragOperationEvery;
}

// Stop the NSTableView implementation getting in the way
- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender
{
	return [self draggingEntered:sender];
}

//
// drag a picture file into the portal view to change the cover picture
// 
- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender {
	NSLog(@"performDragOperation:");
	if (![self isInPortalState])
		return NO;
	
	YLSite *site = [_portal selectedSite];
	if (site == NULL)
		return NO;
	
    NSPasteboard *pboard = [sender draggingPasteboard];
	
    if ( [[pboard types] containsObject:NSFilenamesPboardType] ) {
        NSArray *files = [pboard propertyListForType:NSFilenamesPboardType];
        int numberOfFiles = [files count];
        // Perform operation using the list of files
		for (int i = 0; i < numberOfFiles; ++i) {
			NSString *filename = [files objectAtIndex: i];
			NSString *suffix = [[filename componentsSeparatedByString:@"."] lastObject];
			NSArray *suffixes = supportedCoverExtensions;
			if ([filename hasSuffix: @"/"] || [suffixes containsObject: suffix])
				continue;
			[self addPortalPicture:filename forSite:[site name]];
			[self updatePortal];
			break;
		}
    }
    return YES;
}
*/
@end

@implementation NSObject(NSToolTipOwner)
- (NSString *) view: (NSView *)view 
   stringForToolTip: (NSToolTipTag)tag 
			  point: (NSPoint)point 
		   userData: (void *)userData {
	return (NSString *)userData;
}
@end
