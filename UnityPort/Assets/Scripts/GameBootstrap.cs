using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;
using UnityEngine.EventSystems;

// Runtime-generated Unity prototype. Attach to any scene object or let auto-bootstrap create it.
public class GameBootstrap : MonoBehaviour
{
    const int W=12,H=8; const float TILE=1.5f;
    readonly HashSet<Vector2Int> path=new HashSet<Vector2Int>();
    readonly Dictionary<Vector2Int,GameObject> turrets=new Dictionary<Vector2Int,GameObject>();
    readonly List<Enemy> enemies=new List<Enemy>();
    readonly Dictionary<string,int> costs=new Dictionary<string,int>{{"Sentry",50},{"Heavy Cannon",140},{"Gatling",110},{"Rocket",180},{"Tesla",160}};
    Camera cam; Canvas canvas; Text info,status; GameObject menu; string selected="Sentry";
    int money=350,hp=20,wave=1,episode=1,remaining; float spawnTimer; bool playing,waveActive;
    class Enemy { public GameObject go; public float progress,health,speed; }
    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
    static void Boot(){if(FindObjectOfType<GameBootstrap>()==null)new GameObject("ZombieDefenseUnity").AddComponent<GameBootstrap>();}
    void Awake(){
        Application.targetFrameRate=60;
        int[,] pts={{0,3},{1,3},{2,3},{3,3},{3,4},{3,5},{4,5},{5,5},{6,5},{6,4},{6,3},{7,3},{8,3},{9,3},{9,4},{9,5},{10,5},{11,5}};
        for(int i=0;i<pts.GetLength(0);i++)path.Add(new Vector2Int(pts[i,0],pts[i,1]));
        BuildWorld();BuildUI();ShowMenu();
    }
    Material Mat(Color c){var m=new Material(Shader.Find("Standard"));m.color=c;return m;}
    GameObject Shape(PrimitiveType type,string n,Vector3 p,Vector3 s,Color c){var g=GameObject.CreatePrimitive(type);g.name=n;g.transform.position=p;g.transform.localScale=s;g.GetComponent<Renderer>().material=Mat(c);return g;}
    Vector3 Cell(Vector2Int c){return new Vector3(c.x*TILE,0,c.y*TILE);}
    void BuildWorld(){
        RenderSettings.ambientLight=new Color(.45f,.5f,.6f);RenderSettings.fog=true;RenderSettings.fogColor=new Color(.12f,.15f,.18f);RenderSettings.fogDensity=.012f;
        var l=new GameObject("Moonlight").AddComponent<Light>();l.type=LightType.Directional;l.intensity=1.2f;l.transform.rotation=Quaternion.Euler(50,-25,0);
        var cg=new GameObject("Main Camera");cg.tag="MainCamera";cam=cg.AddComponent<Camera>();cg.transform.position=new Vector3(8.25f,17f,11f);cg.transform.LookAt(new Vector3(8.25f,0,5.25f));cam.orthographic=true;cam.orthographicSize=8.8f;
        for(int z=0;z<H;z++)for(int x=0;x<W;x++){var c=new Vector2Int(x,z);Shape(PrimitiveType.Cube,"Tile",Cell(c)+Vector3.down*.08f,new Vector3(TILE-.05f,.16f,TILE-.05f),path.Contains(c)?new Color(.3f,.19f,.13f):((x+z)%2==0?new Color(.08f,.13f,.18f):new Color(.11f,.17f,.22f)));}
        Random.InitState(74129);
        for(int i=0;i<42;i++){float x,z;switch(i%4){case 0:x=Random.Range(-2f,20f);z=Random.Range(-2.8f,-1.6f);break;case 1:x=Random.Range(-2f,20f);z=Random.Range(13.6f,14.8f);break;case 2:x=Random.Range(-2.8f,-1.6f);z=Random.Range(0f,12f);break;default:x=Random.Range(19.6f,20.8f);z=Random.Range(0f,12f);break;}
            Shape(PrimitiveType.Cylinder,"Tree trunk",new Vector3(x,1,z),new Vector3(.3f,1.1f,.3f),new Color(.16f,.09f,.05f));Shape(PrimitiveType.Sphere,"Tree crown",new Vector3(x,2.5f,z),Vector3.one*1.6f,new Color(.025f,.1f,.065f));}
    }
    void BuildUI(){
        if(FindObjectOfType<EventSystem>()==null)new GameObject("EventSystem",typeof(EventSystem),typeof(StandaloneInputModule));
        var go=new GameObject("Game UI");canvas=go.AddComponent<Canvas>();canvas.renderMode=RenderMode.ScreenSpaceOverlay;var scaler=go.AddComponent<CanvasScaler>();scaler.uiScaleMode=CanvasScaler.ScaleMode.ScaleWithScreenSize;scaler.referenceResolution=new Vector2(1280,720);go.AddComponent<GraphicRaycaster>();
        info=Label(canvas.transform,"",22,new Vector2(18,-18),new Vector2(420,130),TextAnchor.UpperLeft);status=Label(canvas.transform,"Build a turret, then start a wave.",18,new Vector2(18,18),new Vector2(700,40),TextAnchor.LowerLeft);
        var panel=Panel(canvas.transform,new Vector2(18,165),new Vector2(270,50));var drop=panel.gameObject.AddComponent<Dropdown>();drop.options.Clear();foreach(var k in costs.Keys)drop.options.Add(new Dropdown.OptionData(k));drop.onValueChanged.AddListener(i=>selected=drop.options[i].text);
        ButtonAt("BUILD: TAP EMPTY TILE",new Vector2(18,220),new Vector2(270,48),()=>status.text="Selected "+selected+". Tap an empty tile.");
        ButtonAt("START NEXT WAVE",new Vector2(18,272),new Vector2(270,48),StartWave);
        ButtonAt("PAUSE / MAIN MENU",new Vector2(18,324),new Vector2(270,48),ShowMenu);
    }
    Text Label(Transform parent,string value,int size,Vector2 pos,Vector2 dims,TextAnchor anchor){var g=new GameObject("Text");g.transform.SetParent(parent,false);var r=g.AddComponent<RectTransform>();r.anchorMin=new Vector2(0,1);r.anchorMax=new Vector2(0,1);r.pivot=new Vector2(0,1);r.anchoredPosition=pos;r.sizeDelta=dims;var t=g.AddComponent<Text>();t.font=Resources.GetBuiltinResource<Font>("Arial.ttf");t.text=value;t.fontSize=size;t.color=Color.white;t.alignment=anchor;return t;}
    Image Panel(Transform parent,Vector2 pos,Vector2 size){var g=new GameObject("Panel");g.transform.SetParent(parent,false);var r=g.AddComponent<RectTransform>();r.anchorMin=new Vector2(0,1);r.anchorMax=new Vector2(0,1);r.pivot=new Vector2(0,1);r.anchoredPosition=pos;r.sizeDelta=size;var im=g.AddComponent<Image>();im.color=new Color(.025f,.06f,.09f,.95f);return im;}
    void ButtonAt(string value,Vector2 pos,Vector2 size,UnityEngine.Events.UnityAction action){var im=Panel(canvas.transform,pos,size);var b=im.gameObject.AddComponent<Button>();b.targetGraphic=im;b.onClick.AddListener(action);var t=Label(im.transform,value,17,Vector2.zero,size,TextAnchor.MiddleCenter);t.rectTransform.anchorMin=Vector2.zero;t.rectTransform.anchorMax=Vector2.one;t.rectTransform.offsetMin=Vector2.zero;t.rectTransform.offsetMax=Vector2.zero;}
    void ShowMenu(){playing=false;if(menu)Destroy(menu);menu=new GameObject("Nightfall Menu");menu.transform.SetParent(canvas.transform,false);var im=menu.AddComponent<Image>();im.color=new Color(.01f,.02f,.04f,.96f);var r=menu.GetComponent<RectTransform>();r.anchorMin=Vector2.zero;r.anchorMax=Vector2.one;r.offsetMin=Vector2.zero;r.offsetMax=Vector2.zero;
        var title=Label(menu.transform,"NIGHTFALL\nZOMBIE TOWER DEFENSE 3D",36,new Vector2(0,-90),new Vector2(800,130),TextAnchor.MiddleCenter);title.rectTransform.anchorMin=new Vector2(.5f,1);title.rectTransform.anchorMax=new Vector2(.5f,1);title.rectTransform.pivot=new Vector2(.5f,1);
        MenuButton("PLAY / CONTINUE",-260,()=>{playing=true;if(menu)Destroy(menu);menu=null;if(!waveActive)StartWave();});
        MenuButton("RESTART RUN",-325,()=>{money=350;hp=20;wave=1;episode=1;foreach(var e in enemies)if(e.go)Destroy(e.go);enemies.Clear();foreach(var t in turrets.Values)if(t)Destroy(t);turrets.Clear();playing=true;if(menu)Destroy(menu);menu=null;StartWave();});
    }
    void MenuButton(string value,float y,UnityEngine.Events.UnityAction action){var g=new GameObject(value);g.transform.SetParent(menu.transform,false);var r=g.AddComponent<RectTransform>();r.anchorMin=new Vector2(.5f,1);r.anchorMax=new Vector2(.5f,1);r.pivot=new Vector2(.5f,1);r.anchoredPosition=new Vector2(0,y);r.sizeDelta=new Vector2(350,52);var im=g.AddComponent<Image>();im.color=new Color(.04f,.15f,.22f);var b=g.AddComponent<Button>();b.targetGraphic=im;b.onClick.AddListener(action);var t=Label(g.transform,value,20,Vector2.zero,new Vector2(350,52),TextAnchor.MiddleCenter);t.rectTransform.anchorMin=Vector2.zero;t.rectTransform.anchorMax=Vector2.one;t.rectTransform.offsetMin=Vector2.zero;t.rectTransform.offsetMax=Vector2.zero;}
    void StartWave(){if(waveActive)return;waveActive=true;remaining=8+wave*2;spawnTimer=.2f;status.text="Wave "+wave+" incoming!";}
    void Update(){
        info.text="NIGHTFALL // DEFENSE\nEpisode "+episode+"/100 • Wave "+wave+"/5\nCash: $"+money+"    Base HP: "+hp+"\nTurrets: "+turrets.Count+"   Enemies: "+enemies.Count;
        if(!playing)return;
        if(waveActive){spawnTimer-=Time.deltaTime;if(spawnTimer<=0&&remaining>0){SpawnEnemy();remaining--;spawnTimer=Mathf.Max(.35f,1.1f-episode*.006f);}if(remaining==0&&enemies.Count==0){waveActive=false;money+=35;if(wave<5)wave++;else{wave=1;episode=Mathf.Min(100,episode+1);}status.text="Wave cleared! +$35";}}
        var cells=new List<Vector2Int>(path);
        for(int i=enemies.Count-1;i>=0;i--){var e=enemies[i];if(!e.go){enemies.RemoveAt(i);continue;}e.progress+=e.speed*Time.deltaTime;int idx=Mathf.FloorToInt(e.progress);if(idx>=cells.Count){hp--;Destroy(e.go);enemies.RemoveAt(i);continue;}Vector3 a=Cell(cells[idx])+Vector3.up*.5f;Vector3 b=Cell(cells[Mathf.Min(idx+1,cells.Count-1)])+Vector3.up*.5f;e.go.transform.position=Vector3.Lerp(a,b,e.progress-idx);}
        foreach(var kv in turrets){var p=kv.Value.transform.position;Enemy target=null;float best=5.5f;foreach(var e in enemies)if(e.go&&Vector3.Distance(p,e.go.transform.position)<best){best=Vector3.Distance(p,e.go.transform.position);target=e;}if(target!=null){target.health-=Time.deltaTime*35;if(target.health<=0){money+=10;Destroy(target.go);target.go=null;}}}
        if(hp<=0){status.text="BASE DESTROYED — restart run.";playing=false;}
    }
    void SpawnEnemy(){var g=Shape(PrimitiveType.Capsule,"Zombie",Cell(new Vector2Int(0,3))+Vector3.up*.5f,Vector3.one,new Color(.28f,.65f,.25f));enemies.Add(new Enemy{go=g,progress=0,health=70+episode*10,speed=1f+wave*.08f});}
    void OnGUI(){if(!playing||menu!=null)return;if(Event.current.type==EventType.MouseDown&&Event.current.button==0){Vector2 p=Event.current.mousePosition;p.y=Screen.height-p.y;var ray=cam.ScreenPointToRay(p);if(new Plane(Vector3.up,Vector3.zero).Raycast(ray,out float d)){Vector3 hit=ray.GetPoint(d);var c=new Vector2Int(Mathf.RoundToInt(hit.x/TILE),Mathf.RoundToInt(hit.z/TILE));if(c.x<0||c.x>=W||c.y<0||c.y>=H)return;if(path.Contains(c)){status.text="Blocked: zombie path.";return;}if(turrets.ContainsKey(c)){status.text="Tile already occupied.";return;}if(money<costs[selected]){status.text="Not enough cash.";return;}money-=costs[selected];Color col=selected=="Tesla"?Color.magenta:selected=="Rocket"?Color.red:selected=="Gatling"?Color.yellow:new Color(.2f,.8f,1f);turrets[c]=Shape(PrimitiveType.Cylinder,selected+" Turret",Cell(c)+Vector3.up*.45f,new Vector3(.65f,.45f,.65f),col);status.text=selected+" turret placed.";}}}
}