export const OKR_CONTENT_MAX_WIDTH: number = 720;

@ComponentV2
export struct PageShell {
  @BuilderParam content: () => void;

  build() {
    Column() {
      this.content()
    }
    .width('100%')
    .height('100%')
    .constraintSize({ maxWidth: OKR_CONTENT_MAX_WIDTH })
    .alignSelf(ItemAlign.Center)
  }
}

/**
 * 白瓷卡片：一张白卡 + 1px 描边 + 极淡投影。
 * 不做嵌套——组内元素之间用 OkrHairline 细分隔线，而不是再塞一层卡片。
 */
@ComponentV2
export struct SectionCard {
  @Param cardTitle: string = '';
  @Param cardHint: string = '';
  @Param headerAction: string = '';
  /** 无标题时整卡收紧内边距，用于只放内容的容器 */
  @Param flush: boolean = false;
  @Event onHeaderAction: () => void = (): void => {
  };
  @BuilderParam content: () => void;

  build() {
    Column({ space: 12 }) {
      if (this.cardTitle.length > 0) {
        Row() {
          Text(this.cardTitle)
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.okr_text_secondary'))
          Blank()
          if (this.cardHint.length > 0) {
            Text(this.cardHint)
              .fontSize(11)
              .fontColor($r('app.color.okr_text_tertiary'))
          }
          if (this.headerAction.length > 0) {
            Text(this.headerAction)
              .fontSize(12)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.okr_text_primary'))
              .margin({ left: 10 })
              .onClick((): void => {
                this.onHeaderAction();
              })
          }
        }
        .width('100%')
        .alignItems(VerticalAlign.Bottom)
      }
      this.content()
    }
    .width('100%')
    .padding(this.flush ? 0 : 18)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor($r('app.color.okr_card'))
    .borderRadius(16)
    .border({ width: 1, color: $r('app.color.okr_divider') })
    .shadow({ radius: 12, color: '#14111619', offsetX: 0, offsetY: 4 })
  }
}

/** 卡片之间留白：白瓷版把纵向间距收到 12 */
export const OKR_CARD_GAP: number = 12;
