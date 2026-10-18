import {
  OkrIdeaItem,
  okrDueText,
  okrEmptyIdea,
  okrIsOverdue,
  okrPriorityColor,
  okrPriorityLabel
} from '../model/OkrModel';
import { OKR_STORE } from '../store/OkrStore';
import { OkrTagChip } from './OkrCommon';

@ComponentV2
export struct IdeaCard {
  @Param ideaId: string = '';
  @Event onOpen: (ideaId: string) => void = (ideaId: string): void => {
  };

  private item(): OkrIdeaItem {
    const found: OkrIdeaItem | undefined = OKR_STORE.findIdea(this.ideaId);
    return found === undefined ? okrEmptyIdea() : found;
  }

  private titleColor(): ResourceColor {
    if (this.item().done) {
      return $r('app.color.okr_text_tertiary');
    }
    return $r('app.color.okr_text_primary');
  }

  private deco(): TextDecorationOptions {
    if (this.item().done) {
      return { type: TextDecorationType.LineThrough, color: '#AEB3BC' };
    }
    return { type: TextDecorationType.None };
  }

  private dueColor(): ResourceColor {
    if (okrIsOverdue(this.item().dueDate, this.item().done)) {
      return $r('app.color.okr_danger');
    }
    return $r('app.color.okr_text_tertiary');
  }

  private hasKr(): boolean {
    return this.item().krId.length > 0 && OKR_STORE.krTitle(this.item().krId).length > 0;
  }

  build() {
    Row({ space: 10 }) {
      Checkbox({ name: this.ideaId, group: 'okr_idea' })
        .shape(CheckBoxShape.CIRCLE)
        .width(20)
        .height(20)
        .select(this.item().done)
        .selectedColor($r('app.color.okr_primary'))
        .onChange((checked: boolean): void => {
          OKR_STORE.toggleIdeaDone(this.ideaId);
        })

      Column({ space: 8 }) {
        Text(this.item().title)
          .width('100%')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.titleColor())
          .decoration(this.deco())
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Scroll() {
          Row({ space: 6 }) {
            Text(okrPriorityLabel(this.item().priority))
              .fontSize(11)
              .fontWeight(FontWeight.Bold)
              .fontColor(okrPriorityColor(this.item().priority))
              .padding({ left: 6, right: 6, top: 2, bottom: 2 })
              .borderRadius(4)
              .backgroundColor($r('app.color.okr_track'))

            if (this.item().dueDate > 0) {
              Text(okrDueText(this.item().dueDate))
                .fontSize(11)
                .fontColor(this.dueColor())
            }

            if (this.hasKr()) {
              Text(`KR · ${OKR_STORE.krTitle(this.item().krId)}`)
                .fontSize(11)
                .fontColor($r('app.color.okr_primary'))
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .constraintSize({ maxWidth: 160 })
            }

            ForEach(this.item().tags, (tagName: string) => {
              OkrTagChip({
                chipText: tagName,
                colorIndex: OKR_STORE.tagColorIndex(tagName),
                solid: false
              })
            }, (tagName: string): string => tagName)
          }
          .alignItems(VerticalAlign.Center)
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .width('100%')
        .height(22)
        .edgeEffect(EdgeEffect.None)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .onClick((): void => {
        this.onOpen(this.ideaId);
      })
    }
    .width('100%')
    .padding(14)
    .alignItems(VerticalAlign.Top)
    .backgroundColor($r('app.color.okr_card'))
    .borderRadius(14)
  }
}
