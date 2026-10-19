import {
  OkrFlowState,
  okrClampPercent,
  okrFlowColor
} from '../model/OkrAnalytics';

/**
 * 白瓷 Porcelain 视觉套件
 * 规则：不嵌套卡片；状态由填充色承担；数字等宽右对齐；一个实心按钮。
 */

/** 页头：eyebrow（等宽小字）+ 大标题 + 一句副标题 */
@ComponentV2
export struct OkrPageHeader {
  @Param title: string = '';
  @Param eyebrow: string = '';
  @Param sub: string = '';

  build() {
    Column() {
      if (this.eyebrow.length > 0) {
        Text(this.eyebrow)
          .fontSize(10)
          .fontWeight(FontWeight.Medium)
          .letterSpacing(1.6)
          .fontColor($r('app.color.okr_text_tertiary'))
          .margin({ bottom: 11 })
      }
      Text(this.title)
        .fontSize(29)
        .fontWeight(FontWeight.Bold)
        .letterSpacing(-0.7)
        .fontColor($r('app.color.okr_text_primary'))
      if (this.sub.length > 0) {
        Text(this.sub)
          .fontSize(13)
          .fontWeight(FontWeight.Lighter)
          .lineHeight(20)
          .fontColor($r('app.color.okr_text_secondary'))
          .margin({ top: 8 })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}

/**
 * 签名组件：双层刻度进度条
 * 深色填充 = 实际进度，竖线游标 = 按时间推算的应达线。
 * 填充色直接承担状态：靛蓝推进中 / 灰停滞 / 砖红落后。
 */
@ComponentV2
export struct OkrMeter {
  @Param actual: number = 0;
  /** < 0 表示这条 KR 没有可推算的节奏，不画游标 */
  @Param expected: number = -1;
  @Param state: OkrFlowState = OkrFlowState.OnTrack;
  @Param showLabel: boolean = true;

  private fillPercent(): number {
    return okrClampPercent(this.actual);
  }

  private tickPercent(): number {
    return okrClampPercent(this.expected);
  }

  private tickVisible(): boolean {
    return this.expected >= 0;
  }

  private labelText(): string {
    return `应达 ${this.tickPercent()}%`;
  }

  private fillColor(): string {
    return okrFlowColor(this.state);
  }

  build() {
    Column() {
      Stack({ alignContent: Alignment.Start }) {
        Row()
          .width('100%')
          .height(5)
          .borderRadius(3)
          .backgroundColor($r('app.color.okr_track'))

        Row()
          .width(`${this.fillPercent()}%`)
          .height(5)
          .borderRadius(3)
          .backgroundColor(this.fillColor())

        if (this.tickVisible()) {
          Row()
            .width(2)
            .height(13)
            .backgroundColor($r('app.color.okr_text_primary'))
            .borderRadius(1)
            .offset({ x: `${this.tickPercent()}%` })
        }
      }
      .width('100%')
      .height(13)

      if (this.showLabel && this.tickVisible()) {
        Text(this.labelText())
          .fontSize(9.5)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.okr_text_tertiary'))
          .margin({ top: 3 })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}

/**
 * KR 账本行：名称 + 右对齐百分比，第二行是等宽小字的数字与状态
 */
@ComponentV2
export struct OkrLedgerLine {
  @Param leftText: string = '';
  @Param rightText: string = '';
  @Param tone: OkrFlowState = OkrFlowState.OnTrack;
  @Param faint: boolean = false;

  private rightColor(): ResourceColor {
    if (this.faint) {
      return $r('app.color.okr_text_tertiary');
    }
    if (this.tone === OkrFlowState.Behind) {
      return $r('app.color.okr_danger');
    }
    if (this.tone === OkrFlowState.Stalled) {
      return $r('app.color.okr_text_tertiary');
    }
    return $r('app.color.okr_primary');
  }

  build() {
    Row({ space: 10 }) {
      Text(this.leftText)
        .fontSize(10.5)
        .fontColor($r('app.color.okr_text_tertiary'))
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text(this.rightText)
        .fontSize(10.5)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.rightColor())
    }
    .width('100%')
    .alignItems(VerticalAlign.Bottom)
  }
}

/** 卡片头部：左侧标题，右侧等宽小字或操作 */
@ComponentV2
export struct OkrCardHead {
  @Param title: string = '';
  @Param hint: string = '';
  @Param action: string = '';
  @Param tone: OkrFlowState = OkrFlowState.OnTrack;
  @Param monoTitle: boolean = false;
  @Event onAction: () => void = (): void => {
  };

  private hintColor(): ResourceColor {
    if (this.tone === OkrFlowState.Behind) {
      return $r('app.color.okr_danger');
    }
    if (this.tone === OkrFlowState.Stalled) {
      return $r('app.color.okr_text_tertiary');
    }
    if (this.tone === OkrFlowState.OnTrack) {
      return $r('app.color.okr_text_primary');
    }
    return $r('app.color.okr_text_tertiary');
  }

  build() {
    Row({ space: 10 }) {
      Text(this.title)
        .fontSize(this.monoTitle ? 10 : 12)
        .fontWeight(FontWeight.Medium)
        .letterSpacing(this.monoTitle ? 1.4 : 0)
        .fontColor(this.monoTitle ? $r('app.color.okr_text_tertiary') : $r('app.color.okr_text_secondary'))

      Blank()

      if (this.hint.length > 0) {
        Text(this.hint)
          .fontSize(11)
          .fontColor(this.hintColor())
      }

      if (this.action.length > 0) {
        Text(this.action)
          .fontSize(12)
          .fontColor($r('app.color.okr_text_secondary'))
          .margin({ left: 10 })
          .onClick((): void => {
            this.onAction();
          })
      }
    }
    .width('100%')
    .alignItems(VerticalAlign.Bottom)
  }
}

/** 主操作：纯墨色实心；次操作：描边 */
@ComponentV2
export struct OkrSolidButton {
  @Param label: string = '';
  @Param danger: boolean = false;
  @Param full: boolean = false;
  @Event onTap: () => void = (): void => {
  };

  build() {
    Button(this.label)
      .height(38)
      .padding({ left: 18, right: 18 })
      .fontSize(13)
      .fontWeight(FontWeight.Medium)
      .borderRadius(10)
      .backgroundColor(this.danger ? $r('app.color.okr_danger_soft') : $r('app.color.okr_text_primary'))
      .fontColor(this.danger ? $r('app.color.okr_danger') : $r('app.color.okr_on_primary'))
      .width(this.full ? '100%' : undefined)
      .onClick((): void => {
        this.onTap();
      })
  }
}

/** 次操作：描边按钮 */
@ComponentV2
export struct OkrGhostButton {
  @Param label: string = '';
  @Param full: boolean = false;
  @Event onTap: () => void = (): void => {
  };

  build() {
    Button(this.label)
      .height(38)
      .padding({ left: 18, right: 18 })
      .fontSize(13)
      .fontWeight(FontWeight.Medium)
      .borderRadius(10)
      .backgroundColor($r('app.color.okr_card'))
      .fontColor($r('app.color.okr_text_primary'))
      .border({ width: 1, color: $r('app.color.okr_rule_strong') })
      .width(this.full ? '100%' : undefined)
      .onClick((): void => {
        this.onTap();
      })
  }
}

/** 纯文字操作 */
@ComponentV2
export struct OkrTextButton {
  @Param label: string = '';
  @Event onTap: () => void = (): void => {
  };

  build() {
    Text(this.label)
      .fontSize(13)
      .fontColor($r('app.color.okr_text_secondary'))
      .padding({ left: 10, right: 10, top: 10, bottom: 10 })
      .onClick((): void => {
        this.onTap();
      })
  }
}

/** 卡内细分隔线 */
@ComponentV2
export struct OkrHairline {
  build() {
    Divider()
      .strokeWidth(1)
      .color($r('app.color.okr_divider'))
  }
}
