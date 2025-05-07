import hilog from '@ohos.hilog';
import promptAction from '@ohos.promptAction';
import http from '@ohos.net.http'; // 使用默认导入
// HttpRequest, HttpResponse, ResponseCode, RequestMethod 将通过 http.X 访问或类型推断
import util from '@ohos.util';
// 移除了 @ohos.filepicker 和 @ohos.file.fs 的导入
import type resourceManager from '@ohos.resourceManager';

const TAG: string = 'RollCallComponent';
const DOMAIN: number = 0xFF00;
const BASE_URL: string = "http://192.168.8.108:8080/api"; // 确保IP正确

interface Clazz { id: string; name: string; }
interface Student { id: string; name: string; classId?: string; }
// ApiResponse 接口可以保留，因为网络请求仍可能返回类似结构
interface ApiResponse { message?: string; importedCount?: number; /* 其他可能的通用字段 */ }

interface SelectOption { value: string; }
// HttpFormDataPart 接口已移除，因为不再进行文件表单上传

@Component
export struct RollCallComponent {
  @State classList: Clazz[] = [];
  @State classDisplayNames: string[] = ["没有可用的班级"];
  @State selectedClassIndex: number = 0;
  @State selectedClassId: string | null = null;
  @State rollCallResult: string = "";
  @State statusText: string = "";
  @State isLoading: boolean = false;

  @Prop appResourceManager: resourceManager.ResourceManager;

  private httpRequest = http.createHttp(); // 类型由TS推断
  private textDecoder: util.TextDecoder = new util.TextDecoder('utf-8');

  private async getString(resource: Resource, defaultValue: string): Promise<string> {
    if (this.appResourceManager) {
      try {
        // !!! 再次确认 getStringValue 是否真的返回 Promise !!!
        const value: string = await this.appResourceManager.getStringValue(resource);
        return value;
      } catch (e) {
        hilog.error(DOMAIN, TAG, "Error getting string resource: %{public}s", (e as Error).message);
        return defaultValue;
      }
    }
    hilog.warn(DOMAIN, TAG, "getString: ResourceManager not available");
    return defaultValue;
  }

  async aboutToAppear(): Promise<void> {
    hilog.info(DOMAIN, TAG, 'RollCallComponent aboutToAppear');
    this.rollCallResult = await this.getString($r('app.string.start_roll_call_button'), "点名结果...");
    this.statusText = await this.getString($r('app.string.status_loading_classes'), "加载中...");
    await this.fetchClasses();
  }

  async fetchClasses(): Promise<void> {
    this.isLoading = true;
    this.statusText = await this.getString($r('app.string.status_loading_classes'), "正在加载...");
    try {
      const response = await this.httpRequest.request(`${BASE_URL}/classes`, {
        method: http.RequestMethod.GET, connectTimeout: 10000, readTimeout: 10000
      });

      if (response.responseCode === http.ResponseCode.OK && response.result) {
        let resultStr: string;
        if (response.result instanceof ArrayBuffer) {
          resultStr = this.textDecoder.decode(new Uint8Array(response.result));
        } else if (typeof response.result === 'string') {
          resultStr = response.result;
        } else {
          this.handleNetworkError("获取班级列表失败: 未知响应类型", response.responseCode as number, undefined);
          return;
        }
        const fetchedClasses: Clazz[] = JSON.parse(resultStr);
        this.classList = fetchedClasses;
        if (fetchedClasses.length > 0) {
          this.classDisplayNames = fetchedClasses.map(c => c.name);
          this.selectedClassIndex = 0; this.selectedClassId = fetchedClasses[0].id;
          this.statusText = "班级列表已加载";
        } else {
          this.classDisplayNames = ["没有可用的班级"]; this.selectedClassId = null; this.statusText = "无班级数据";
        }
      } else { this.handleNetworkError("获取班级列表失败", response.responseCode as number, response.result); }
    } catch (error) { this.handleNetworkError("获取班级列表出错", undefined, undefined, error as Error | object); }
    finally { this.isLoading = false; }
  }

  async performRollCall(): Promise<void> {
    if (!this.selectedClassId) { promptAction.showToast({ message: "请先选择一个班级" }); return; }
    this.isLoading = true;
    this.statusText = await this.getString($r('app.string.status_roll_calling'), "点名中...");
    this.rollCallResult = "...";
    try {
      const response = await this.httpRequest.request(`${BASE_URL}/classes/${this.selectedClassId}/random-student`, {
        method: http.RequestMethod.GET
      });
      if (response.responseCode === http.ResponseCode.OK && response.result) {
        let resultStr: string;
        if (response.result instanceof ArrayBuffer) { resultStr = this.textDecoder.decode(new Uint8Array(response.result)); }
        else if (typeof response.result === 'string') { resultStr = response.result; }
        else { this.handleNetworkError("点名失败: 未知响应类型", response.responseCode as number, undefined); return; }
        const student = JSON.parse(resultStr) as Student;
        if (student && student.name) {
          this.rollCallResult = `抽中: ${student.name} (ID: ${student.id})`; this.statusText = "点名完成";
        } else { this.rollCallResult = "该班级没有学生或数据格式错误"; this.statusText = "点名结果异常"; }
      } else if (response.responseCode === http.ResponseCode.NOT_FOUND) {
        this.rollCallResult = "该班级没有学生或班级不存在"; this.statusText = "点名失败 (404)";
      } else { this.handleNetworkError("点名请求失败", response.responseCode as number, response.result); }
    } catch (error) { this.handleNetworkError("点名请求出错", undefined, undefined, error as Error | object); this.rollCallResult = "点名出错"; }
    finally { this.isLoading = false; }
  }

  // openFilePickerAndUpload 和 uploadExcelFile 方法已移除

  handleNetworkError(message: string, code?: number, responseBody?: ArrayBuffer | string | object, exception?: Error | object): void {
    let detailedMessage = message;
    if (code) detailedMessage += ` (状态码: ${code})`;
    let bodyString = "";
    if (responseBody) {
      if (typeof responseBody === 'string') { bodyString = responseBody; }
      else if (responseBody instanceof ArrayBuffer) {
        try { bodyString = this.textDecoder.decode(new Uint8Array(responseBody)); }
        catch (e) { bodyString = "无法解码响应体 (ArrayBuffer)"; }
      } else if (typeof responseBody === 'object' && responseBody !== null) {
        try { bodyString = JSON.stringify(responseBody); }
        catch (e) { bodyString = "无法序列化响应体对象";}
      } else { bodyString = "响应体类型未知或为null"; }
      detailedMessage += `\n响应: ${bodyString.substring(0, 200)}`;
    }
    if (exception) {
      const error = exception as Error;
      detailedMessage += `\n异常: ${error?.message ?? JSON.stringify(exception)}`;
      if (error?.stack) detailedMessage += `\nStack: ${error.stack.substring(0,200)}`;
    }
    hilog.error(DOMAIN, TAG, '%{public}s', detailedMessage);
    this.statusText = `错误: ${message.split('\n')[0].split('|')[0].trim()}`;
    promptAction.showToast({ message: "操作失败，请检查网络或服务器日志" });
  }

  build() {
    Column() {
      Text("选择班级:")
        .fontSize(16).margin({ top: 16, bottom: 8 }).alignSelf(ItemAlign.Start)
      Select(this.classDisplayNames.map((name): SelectOption => ({ value: name })))
        .selected(this.selectedClassIndex)
        .onSelect(async (index: number) => {
          this.selectedClassIndex = index;
          if (this.classList.length > 0 && index >= 0 && index < this.classList.length) {
            this.selectedClassId = this.classList[index].id;
            this.rollCallResult = await this.getString($r('app.string.start_roll_call_button'), "点名结果...");
            hilog.info(DOMAIN, TAG, '选中的班级 ID: %{public}s', this.selectedClassId ?? 'null');
          } else { this.selectedClassId = null; }
        })
        .enabled(!this.isLoading && this.classList.length > 0 && this.classDisplayNames[0] !== "没有可用的班级")
        .width('90%').height(48)

      Button("开始点名")
        .onClick(async () => await this.performRollCall()) // 调用异步方法
        .enabled(!this.isLoading && !!this.selectedClassId)
        .margin({ top: 16 }).width('90%')

      Text(this.rollCallResult)
        .fontSize(20).fontWeight(FontWeight.Bold).textAlign(TextAlign.Center)
        .margin({ top: 24, bottom:10 }).width('90%').height(60)

      // “导入学生名册”按钮已移除
      // Button("导入学生名册 (Excel)").onClick(async () => await this.openFilePickerAndUpload())
      //   .enabled(!this.isLoading && !!this.selectedClassId) // 如果要保留UI但禁用功能，可以这样
      //   .margin({ top: 20 }).width('90%')
      //   .backgroundColor(Color.Gray) // 例如，视觉上禁用

      Text(this.statusText)
        .fontSize(14).fontColor(Color.Gray).textAlign(TextAlign.Center)
        .margin({ top: 16 }).visibility(this.statusText ? Visibility.Visible : Visibility.Hidden)

      if (this.isLoading) {
        LoadingProgress().width(50).height(50).margin({ top: 10 }).color($r('app.color.primary_color'))
      }
    }
    .width('100%').height('100%').padding(16).alignItems(HorizontalAlign.Center)
  }
}