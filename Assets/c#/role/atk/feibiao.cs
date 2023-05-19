using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class feibiao : MonoBehaviour
{
    public float speed = 2f;
    public Vector3 feiV3; //飞镖向量
    public Vector3 target; //目标坐标
    public Vector3 playerM;//player移动向量
    public bool isFly=false;
    public Sprite complate;
    public Animator roleAnimator;
    public Transform roleTranform;
    // Start is called before the first frame update
    void Start()
    {
        speed = 2f;
        roleTranform = GameObject.Find("player").transform.Find("role");
        //动画
        roleAnimator = roleTranform.GetComponent<Animator>();

        //在加载新场景时不销毁脚本挂载的对象
        DontDestroyOnLoad(gameObject);
        if (GameObject.Find(this.name).gameObject != this.gameObject)
            Destroy(this.gameObject);


      //向量转化角度
        Vector3 tpos = transform.position;
        feiV3 = target - tpos;

        Vector3 from = Vector3.right;
        Vector3 to = feiV3;
        transform.rotation = Quaternion.FromToRotation(from, to);
        if (feiV3.x < 0) transform.localScale = new Vector3(transform.localScale.x, -1 * transform.localScale.y, transform.localScale.z);

        //人物跟随飞爪旋转
        Vector3 roleScale = roleTranform.localScale;
        GameObject.Find("player").transform.Find("role").transform.localScale =
            new Vector3((feiV3.x>0?1:feiV3.x<0?-1:0)*Mathf.Abs(roleScale.x) ,
           roleScale.y, roleScale.z);

    }
    // Update is called once per frame
    void Update()
    {

        //Debug.DrawLine(transform.position, GameObject.Find("player").transform.position, Color.yellow);
        if (Mathf.Abs( transform.position.x - target.x)< 0.1)    
        {
           RaycastHit2D hit = Physics2D.Raycast(transform.position, new Vector2(0,0), 1f, LayerMask.GetMask("屋檐"));

            //如果碰到以后
           if (hit.collider != null)
           {
                transform.GetComponent<SpriteRenderer>().sprite = complate;
                Vector3 playerPos = GameObject.Find("player").transform.position;
                Vector3 pos = transform.position;

                    playerM = new Vector3(pos.x - playerPos.x, pos.y - playerPos.y, pos.z - playerPos.z);
                    isFly = true;
                     roleAnimator.SetBool("isFly", isFly);
                      GameObject.Find("player").transform.rotation = transform.rotation;
             //  if (feiV3.x < 0) GameObject.Find("player").transform.Find("role").localScale = 
             //           new Vector3(roleTranform.localScale.x* - 1 , roleTranform.localScale.y,
             //bcbw             roleTranform.localScale.z);

                if (isFly)
                {

                    GameObject.Find("player").transform.position += speed * playerM * Time.deltaTime;
                    if (Mathf.Abs(playerPos.x - pos.x) < 0.5)
                    {
                        isFly = false;
                        cancel();
                        GameObject.Find("player").transform.rotation = Quaternion.Euler(0, 0, 0);
                    }
                }

            }
            else {
                cancel();

            }
        }
        else
        {
                transform.position += feiV3 * speed * Time.deltaTime;

        }
        
    }

    private void cancel()
    {
        Destroy(this.gameObject);
        roleAnimator.SetBool("ischong", false);
        roleAnimator.SetBool("isFly", false);
    }
 //  private void directionOne()
 //  {
 //      if (Mathf.Abs(feiV3.x)!= 0)
 //      {
 //          feiV3.x *= 1 / Mathf.Abs(feiV3.x);
 //      }
 //      if (Mathf.Abs(feiV3.y) != 0)
 //      {
 //          feiV3.y *= 1 / Mathf.Abs(feiV3.y);
 //      }
 //      if (Mathf.Abs(feiV3.z) != 0)
 //      {
 //          feiV3.z *= 1 / Mathf.Abs(feiV3.z);
 //      }
 //      Debug.Log("dir" + feiV3);
 //  }
    
}
