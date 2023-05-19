using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Tilemaps;
public class mapTile : MonoBehaviour
{
    public Tilemap titlemap;
    public TileBase titleStone;
    public Grid grid;
    public GameObject stone;//石头预制体
    private Vector3Int cellPos;

    // Start is called before the first frame update
    void Start()
    {
        grid = GetComponent<Grid>();
    }

    // Update is called once per frame
    void Update()
    {
      //if (Input.GetMouseButtonDown(0))
      // {
      //    Vector3 worldPos = Camera.main.ScreenToWorldPoint(Input.mousePosition);
      //     Vector3Int cellPos = grid.WorldToCell(worldPos);
      //     ExplosionLogic(cellPos);
      //}
    }
    public void ExplosionLogic(Vector3 worldPos)
    {
        cellPos = grid.WorldToCell(worldPos);
        if (titlemap.GetTile(cellPos) == titleStone)
        {
            Vector3 worldPos1 = grid.CellToWorld(cellPos);
                
            Destroy(Instantiate(stone, worldPos1, Quaternion.identity), 1.5f);
            titlemap.SetTile(cellPos, null);
        }
       
    }

}
